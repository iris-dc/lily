import Foundation

/// Buffers interactions and posts them to Laurel: at `batchSize`, or `flushDelay` after the first one, or on `flush()`,
/// and before a sign-out, under `signOutTimeout`; what is still buffered when the session has ended is dropped.
/// Guests are never recorded. Every entry remembers who it was recorded for, so a sign-out between recording and
/// sending drops it instead of charging it to the next user.
final class RemoteInteractionRecorder: InteractionRecorder, SessionObserver {
    private struct Entry {
        let userID: String
        let interaction: Interaction
    }

    private let client: any APIClient
    private let identity: any IdentityProvider
    private let logger: any Logging
    private let batchSize: Int
    private let flushDelay: Duration
    private let maxBuffered: Int
    private let signOutTimeout: Duration
    private let sleep: Sleep
    private var buffer: [Entry] = []
    private var timer: Task<Void, Never>?

    init(client: any APIClient,
         identity: any IdentityProvider,
         logger: any Logging,
         batchSize: Int = AppConfig.Statistics.batchSize,
         flushDelay: Duration = AppConfig.Statistics.flushDelay,
         maxBuffered: Int = AppConfig.Statistics.maxBuffered,
         signOutTimeout: Duration = AppConfig.Statistics.signOutFlushTimeout,
         sleep: @escaping Sleep = systemSleep) {
        self.client = client
        self.identity = identity
        self.logger = logger
        self.batchSize = batchSize
        self.flushDelay = flushDelay
        self.maxBuffered = maxBuffered
        self.signOutTimeout = signOutTimeout
        self.sleep = sleep
    }

    func record(_ interaction: Interaction) {
        guard let userID = identity.currentUserID else {
            logger.debug(.statistics, "Guest \(interaction.kind.rawValue) not recorded")
            return
        }
        buffer.append(Entry(userID: userID, interaction: interaction))
        dropOldestBeyondCapacity()
        logger.debug(.statistics, "Recorded \(interaction.kind.rawValue); buffered: \(buffer.count)")
        if buffer.count >= batchSize {
            Task { await flush() }
        } else if timer == nil {
            armTimer()
        }
    }

    func flush() async {
        timer?.cancel()
        timer = nil
        let entries = buffer
        buffer.removeAll()
        let interactions = entries.filter { $0.userID == identity.currentUserID }.map(\.interaction)
        if interactions.count < entries.count {
            logger.debug(.statistics, "Dropped \(entries.count - interactions.count) interactions of another user")
        }
        guard !interactions.isEmpty else { return }
        await send(interactions)
    }

    /// The Bearer still goes out here, so the user's last interactions are not lost to the sign-out; capped so a stalled
    /// network never holds it (a cancelled send is a warning like any failed one, never retried).
    func sessionWillEnd() async {
        guard !buffer.isEmpty else { return }
        do {
            try await Deadline.within(signOutTimeout, sleep: sleep) { [self] in await flush() }
        } catch {
            logger.warning(.statistics, "Flush before sign-out gave up: \(error)")
        }
    }

    func sessionDidEnd() {
        timer?.cancel()
        timer = nil
        guard !buffer.isEmpty else { return }
        logger.debug(.statistics, "Dropped \(buffer.count) interactions at sign-out")
        buffer.removeAll()
    }

    private func send(_ interactions: [Interaction]) async {
        let request = APIRequest<InteractionReceipt>.post(AppConfig.API.Paths.interactions,
                                                          body: InteractionBatch(interactions: interactions))
        do {
            let receipt = try await client.send(request, failingWith: .unknown)
            logger.info(.statistics, "Sent \(interactions.count) interactions; accepted \(receipt.accepted)")
        } catch {
            logger.warning(.statistics, "Sending \(interactions.count) interactions failed: \(error)")
        }
    }

    private func dropOldestBeyondCapacity() {
        let excess = buffer.count - maxBuffered
        guard excess > 0 else { return }
        buffer.removeFirst(excess)
        logger.debug(.statistics, "Buffer full; dropped the oldest \(excess)")
    }

    /// One timer at a time; a flush before it fires cancels it, and the timer lets go of its slot before it flushes.
    /// `weak self`: the task must not keep a recorder alive for the length of the delay once its owner has let go of it.
    private func armTimer() {
        timer = Task { [weak self, sleep, flushDelay] in
            guard (try? await sleep(flushDelay)) != nil, let self else { return }
            // flush() cancels `timer`, which would be this task and the request in it.
            timer = nil
            await flush()
        }
    }
}
