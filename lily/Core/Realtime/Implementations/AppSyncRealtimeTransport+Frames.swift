import Foundation

/// The reading side: every frame off the socket, the subscribe machinery and the keep-alive watchdog.
extension AppSyncRealtimeTransport {
    /// Reads the socket until it ends; a deliberate teardown cancels this task, which ends the reading quietly.
    func read(_ frames: AsyncThrowingStream<String, any Error>) async {
        do {
            for try await text in frames {
                handle(text)
            }
            guard !Task.isCancelled else { return }
            await connectionEnded(with: nil)
        } catch {
            guard !Task.isCancelled, !(error is CancellationError) else { return }
            await connectionEnded(with: error)
        }
    }

    private func handle(_ text: String) {
        framesSeen += 1
        guard let frame = try? frameDecoder.decode(EventsIncomingFrame.self, from: Data(text.utf8)) else {
            logger.debug(.chat, "Dropped an undecodable realtime frame")
            return
        }
        switch frame.kind {
        case .connectionAck:
            handleAck(frame)
        case .keepAlive, .unsubscribeSuccess, .unsubscribeError:
            break
        case .subscribeSuccess:
            confirmSubscription(frame.id)
        case .subscribeError:
            handleSubscribeError(frame)
        case .data:
            handleData(frame)
        case .broadcastError:
            logger.warning(.chat, "Realtime broadcast error (\(frame.errors?.first?.errorType ?? "?"))")
        case .error:
            handleErrorFrame(frame)
        case nil:
            logger.debug(.chat, "Ignored a \(frame.type) realtime frame")
        }
    }

    private func handleAck(_ frame: EventsIncomingFrame) {
        keepAliveTimeout = frame.keepAliveTimeout ?? AppConfig.Realtime.defaultKeepAliveTimeout
        startWatchdog()
        logger.debug(.chat, "Realtime connection acknowledged")
        settleConnect(with: .success(()))
    }

    private func confirmSubscription(_ id: String?) {
        guard let id, let entry = entries[id] else { return }
        entries[id]?.retries.reset()
        logger.debug(.chat, "Subscribe confirmed on \(entry.channel.path)")
    }

    private func handleData(_ frame: EventsIncomingFrame) {
        guard let id = frame.id, let entry = entries[id] else {
            logger.debug(.chat, "Dropped a delivery for an unknown subscription")
            return
        }
        guard let event = frame.event,
              let envelope = try? envelopeDecoder.decode(RealtimeEnvelope.self, from: Data(event.utf8)) else {
            logger.warning(.chat, "Dropped an undecodable event on \(entry.channel.path)")
            return
        }
        entry.continuation.yield(envelope)
    }

    /// The agreed mapping: `SubscriptionCheckFailed` retries with backoff; `Unauthorized` means the caller may not
    /// have the channel (`.subscribeRefused`: the controller refetches the group); anything else means the API
    /// refuses subscribes now (`.unavailable`: the controller stops and falls to catch-up, never resubscribes).
    private func handleSubscribeError(_ frame: EventsIncomingFrame) {
        guard let id = frame.id, let entry = entries[id] else { return }
        let type = frame.errors?.first?.errorType ?? ""
        if type == AppConfig.Realtime.retriedSubscribeError {
            retrySubscribe(id: id, path: entry.channel.path)
        } else if type.contains(AppConfig.Realtime.unauthorizedSubscribeError) {
            logger.warning(.chat, "Subscribe refused on \(entry.channel.path)")
            finish(id, throwing: .subscribeRefused)
        } else {
            logger.warning(.chat, "Subscribe to \(entry.channel.path) refused by the API (\(type)); catch-up only")
            finish(id, throwing: .unavailable)
        }
    }

    private func retrySubscribe(id: String, path: String) {
        guard let attempt = entries[id]?.retries.attempt, attempt < AppConfig.Realtime.subscribeRetryLimit else {
            logger.warning(.chat, "Subscribe check kept failing on \(path); giving the connection up")
            finish(id, throwing: .connectionLost)
            return
        }
        guard let delay = entries[id]?.retries.next(random: random) else { return }
        logger.warning(.chat, "Subscribe check failed on \(path); retrying in \(Int(delay))s")
        entries[id]?.retryTask?.cancel()
        entries[id]?.retryTask = Task { [weak self, sleep] in
            guard (try? await sleep(.seconds(delay))) != nil, let self else { return }
            entries[id]?.retryTask = nil
            await sendSubscribe(id: id)
        }
    }

    /// An `error` frame naming a subscription is a refusal outside the subscribe flow (a rate limit, a malformed
    /// frame): that stream falls to catch-up; one naming nothing is only logged.
    private func handleErrorFrame(_ frame: EventsIncomingFrame) {
        let type = frame.errors?.first?.errorType ?? "?"
        guard let id = frame.id, let entry = entries[id] else {
            logger.warning(.chat, "Realtime error frame (\(type))")
            return
        }
        logger.warning(.chat, "Realtime error on \(entry.channel.path) (\(type)); catch-up only")
        finish(id, throwing: .unavailable)
    }

    /// Sends the subscribe frame with a token read afresh, as the transport contract requires.
    func sendSubscribe(id: String) async {
        guard let entry = entries[id], let endpoints else { return }
        guard let token = await tokenProvider?.accessToken() else {
            logger.warning(.chat, "No access token for a subscribe; catch-up only")
            finish(id, throwing: .unavailable)
            return
        }
        guard entries[id] != nil else { return }
        do {
            try await socket.send(EventsOutgoingFrame.subscribe(id: id,
                                                                channel: entry.channel.path,
                                                                httpHost: endpoints.httpHost,
                                                                token: token))
        } catch {
            guard entries[id] != nil else { return }
            logger.warning(.chat, "Subscribe send failed on \(entry.channel.path): \(error)")
            finish(id, throwing: .connectionLost)
        }
    }

    /// The socket ended on its own. Before the ack this settles the pending connect with the raw failure (the connect
    /// maps it); after it, every stream ends with `.connectionLost` and the controller reconnects with backoff.
    func connectionEnded(with error: (any Error)?) async {
        guard isConnected else {
            let failure = error ?? RealtimeTransportError.connectionLost
            if connectContinuation != nil {
                settleConnect(with: .failure(failure))
            } else {
                pendingConnectFailure = failure
            }
            return
        }
        logger.warning(.chat, "Realtime socket ended: \(error.map { String(describing: $0) } ?? "finished")")
        isConnected = false
        socketIsOpen = false
        watchdogTask?.cancel()
        watchdogTask = nil
        readerTask?.cancel()
        readerTask = nil
        let open = entries
        entries = [:]
        for entry in open.values {
            entry.retryTask?.cancel()
            entry.continuation.finish(throwing: RealtimeTransportError.connectionLost)
        }
        await socket.close()
    }

    /// Closes a connection whose keep-alives stopped, as the protocol requires of the client. Event-driven: every
    /// frame bumps `framesSeen`, and the watchdog wakes once per window instead of polling.
    func startWatchdog() {
        watchdogTask?.cancel()
        let timeout = keepAliveTimeout
        watchdogTask = Task { [weak self, sleep] in
            var lastSeen = -1
            while !Task.isCancelled {
                guard let self else { return }
                if framesSeen == lastSeen {
                    logger.warning(.chat, "Realtime keep-alive timed out")
                    await connectionEnded(with: nil)
                    return
                }
                lastSeen = framesSeen
                guard (try? await sleep(.seconds(timeout))) != nil else { return }
            }
        }
    }
}
