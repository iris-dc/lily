import Foundation

/// The production socket to the AppSync Events API, over the `EventsSocket` seam so the protocol logic is unit-tested
/// with a fake. One connection: `connect` opens the socket with the caller's access token on the upgrade, sends
/// `connection_init` and completes on `connection_ack`; every subscribe carries a token read afresh; what arrives is
/// routed in `+Frames.swift`. The official `aws-appsync-events-swift` package was probed and declined: it exposes no
/// connect, hides the upgrade's HTTP status (the kill-switch rule needs it) and its non-Sendable client fights the
/// app's main-actor default (`docs/notes/chat.md`).
final class AppSyncRealtimeTransport: RealtimeTransport {
    /// One live subscription, keyed by the client-chosen frame id it subscribed under.
    struct Entry {
        let channel: RealtimeChannel
        let continuation: AsyncThrowingStream<RealtimeEnvelope, any Error>.Continuation
        /// Walks `reconnectBackoffSeconds` across `SubscriptionCheckFailed` retries; `subscribe_success` resets it.
        var retries = Backoff()
        var retryTask: Task<Void, Never>?
    }

    let socket: any EventsSocket
    let tokenProvider: (any AuthTokenProvider)?
    let logger: any Logging
    let sleep: Sleep
    let random: (ClosedRange<Double>) -> Double
    /// Decodes a delivery's event with the backend's date convention, like every other wire read.
    let envelopeDecoder = APIJSONCoding.makeDecoder()
    /// Decodes the frames themselves (no dates), held once instead of per keep-alive.
    let frameDecoder = JSONDecoder()

    var endpoints: AppSyncEndpoints?
    var entries: [String: Entry] = [:]
    var isConnected = false
    /// Whether a socket was opened and not yet closed, so a teardown with nothing open closes nothing.
    var socketIsOpen = false
    /// Counts every incoming frame; the keep-alive watchdog ends a connection whose count stops moving.
    var framesSeen = 0
    var keepAliveTimeout: TimeInterval = AppConfig.Realtime.defaultKeepAliveTimeout
    var readerTask: Task<Void, Never>?
    var watchdogTask: Task<Void, Never>?
    var connectDeadlineTask: Task<Void, Never>?
    var connectContinuation: CheckedContinuation<Void, any Error>?
    /// A socket failure that landed before the connect was parked on its continuation.
    var pendingConnectFailure: (any Error)?

    init(socket: any EventsSocket,
         tokenProvider: (any AuthTokenProvider)?,
         logger: any Logging,
         sleep: @escaping Sleep = systemSleep,
         random: @escaping (ClosedRange<Double>) -> Double = { Double.random(in: $0) }) {
        self.socket = socket
        self.tokenProvider = tokenProvider
        self.logger = logger
        self.sleep = sleep
        self.random = random
    }

    func connect(endpoint: URL) async throws {
        await teardown()
        guard let endpoints = AppSyncEndpoints(endpoint: endpoint) else {
            logger.warning(.chat, "Realtime endpoint is not usable; catch-up only")
            throw RealtimeTransportError.unavailable
        }
        guard let token = await tokenProvider?.accessToken() else {
            logger.warning(.chat, "No access token for the realtime socket; catch-up only")
            throw RealtimeTransportError.unavailable
        }
        try Task.checkCancellation()
        self.endpoints = endpoints
        let frames = socket.open(request: Self.upgradeRequest(endpoints: endpoints, token: token))
        socketIsOpen = true
        readerTask = Task { [weak self] in await self?.read(frames) }
        do {
            try await socket.send(EventsOutgoingFrame.connectionInit())
            try await awaitConnectionAck()
        } catch {
            let mapped = Self.mapConnectFailure(error)
            logConnectFailure(error)
            await teardown()
            throw mapped
        }
        isConnected = true
    }

    func subscribe(to channel: RealtimeChannel) -> AsyncThrowingStream<RealtimeEnvelope, any Error> {
        let (stream, continuation) = AsyncThrowingStream<RealtimeEnvelope, any Error>.makeStream()
        guard isConnected else {
            continuation.finish(throwing: RealtimeTransportError.connectionLost)
            return stream
        }
        let id = UUID().uuidString
        entries[id] = Entry(channel: channel, continuation: continuation)
        continuation.onTermination = { [weak self] reason in
            guard case .cancelled = reason else { return }
            Task { @MainActor [weak self] in self?.consumerLeft(id) }
        }
        Task { [weak self] in await self?.sendSubscribe(id: id) }
        return stream
    }

    func disconnect() async {
        await teardown()
    }

    /// Ends a subscription; one already gone is fine (the consumer left, or the connection ended first).
    func finish(_ id: String, throwing error: RealtimeTransportError) {
        guard let entry = entries.removeValue(forKey: id) else { return }
        entry.retryTask?.cancel()
        entry.continuation.finish(throwing: error)
    }

    /// Resumes the parked connect once; the deadline is disarmed with it.
    func settleConnect(with result: Result<Void, any Error>) {
        connectDeadlineTask?.cancel()
        connectDeadlineTask = nil
        guard let continuation = connectContinuation else { return }
        connectContinuation = nil
        continuation.resume(with: result)
    }

    /// Waits for `connection_ack`, or whatever ends the socket first. A failure that landed before the continuation
    /// was parked is thrown at the parking, so a refused upgrade never leaves a connect waiting on its deadline.
    private func awaitConnectionAck() async throws {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                if let failure = pendingConnectFailure {
                    pendingConnectFailure = nil
                    continuation.resume(throwing: failure)
                } else if Task.isCancelled {
                    continuation.resume(throwing: CancellationError())
                } else {
                    connectContinuation = continuation
                    armConnectDeadline()
                }
            }
        } onCancel: {
            Task { @MainActor [weak self] in self?.settleConnect(with: .failure(CancellationError())) }
        }
    }

    private func armConnectDeadline() {
        connectDeadlineTask?.cancel()
        connectDeadlineTask = Task { [weak self, sleep] in
            guard (try? await sleep(.seconds(AppConfig.Realtime.connectTimeout))) != nil, let self else { return }
            connectDeadlineTask = nil
            logger.warning(.chat, "Realtime connection ack timed out")
            settleConnect(with: .failure(RealtimeTransportError.connectionLost))
        }
    }

    /// Ends everything this transport holds: the parked connect, the reader, the watchdog, every stream, the socket.
    /// `disconnect()` and a failed or superseded connect share it; idempotent.
    private func teardown() async {
        settleConnect(with: .failure(CancellationError()))
        pendingConnectFailure = nil
        readerTask?.cancel()
        readerTask = nil
        watchdogTask?.cancel()
        watchdogTask = nil
        isConnected = false
        endpoints = nil
        let open = entries
        entries = [:]
        for entry in open.values {
            entry.retryTask?.cancel()
            entry.continuation.finish()
        }
        guard socketIsOpen else { return }
        socketIsOpen = false
        await socket.close()
    }

    private func consumerLeft(_ id: String) {
        guard let entry = entries.removeValue(forKey: id) else { return }
        entry.retryTask?.cancel()
        guard isConnected else { return }
        Task { [weak self] in try? await self?.socket.send(EventsOutgoingFrame.unsubscribe(id: id)) }
    }

    /// 401 is a refused token (the controller's expired-session path); any other 4xx is the API refusing connections
    /// (the kill switch flipped: catch-up with no popup); everything else is transient and worth the backoff.
    nonisolated static func mapConnectFailure(_ error: any Error) -> any Error {
        if error is CancellationError || error is RealtimeTransportError { return error }
        guard case EventsSocketFailure.handshakeRefused(let status) = error else {
            return RealtimeTransportError.connectionLost
        }
        if status == AppConfig.API.unauthorizedStatus { return RealtimeTransportError.unauthorized }
        return AppConfig.API.clientErrorStatuses.contains(status)
            ? RealtimeTransportError.unavailable
            : RealtimeTransportError.connectionLost
    }

    private func logConnectFailure(_ error: any Error) {
        switch error {
        case is CancellationError:
            logger.debug(.chat, "Realtime connect cancelled")
        case EventsSocketFailure.handshakeRefused(let status):
            logger.warning(.chat, "Realtime upgrade refused (HTTP \(status))")
        default:
            logger.warning(.chat, "Realtime connect failed: \(error)")
        }
    }

    nonisolated static func upgradeRequest(endpoints: AppSyncEndpoints, token: String) -> URLRequest {
        var request = URLRequest(url: endpoints.socketURL)
        request.setValue(EventsOutgoingFrame.handshakeProtocols(httpHost: endpoints.httpHost, token: token),
                         forHTTPHeaderField: AppConfig.Realtime.subprotocolHeaderField)
        return request
    }
}
