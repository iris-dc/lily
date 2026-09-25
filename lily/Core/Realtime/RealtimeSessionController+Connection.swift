import Foundation

/// Opening, renewing, backing off and closing the connection, and the resume protocol that follows every open.
extension RealtimeSessionController {
    /// One connect at a time: a second caller waits for the one in flight instead of opening a second socket.
    func connect(fresh: Bool) async {
        if let connectionTask {
            await connectionTask.value
            return
        }
        let task = Task { await connectIfWanted(fresh: fresh) }
        connectionTask = task
        await task.value
        if connectionTask == task { connectionTask = nil }
    }

    /// Connects when the app is active, a user is signed in and an endpoint is known; otherwise records why not.
    private func connectIfWanted(fresh: Bool) async {
        guard isActive, let user, state != .connected, state != .connecting else { return }
        connectionGeneration += 1
        let generation = connectionGeneration
        guard let endpoint = await endpointProvider.endpoint() else {
            state = .unavailable
            logger.info(.chat, "Realtime disabled; catch-up only")
            return
        }
        let token = await token(fresh: fresh)
        if tokenProvider != nil, token == nil {
            logger.warning(.chat, "No access token for the realtime connection; staying disconnected")
            return
        }
        state = .connecting
        guard await open(endpoint) else { return }
        guard generation == connectionGeneration, isActive else {
            await transport.disconnect()
            return
        }
        state = .connected
        logger.info(.chat, "Chat connection opened")
        scheduleRenewal(for: token, fresh: fresh)
        subscribe(to: .user(sub: user.id))
        reconcileSubscriptions()
        await runResumeProtocol()
    }

    /// The transport's answer, sorted into what it means for the connection.
    private func open(_ endpoint: URL) async -> Bool {
        do {
            try await transport.connect(endpoint: endpoint)
            return true
        } catch RealtimeTransportError.unauthorized {
            state = .disconnected
            reportExpiredSessionOnce()
        } catch RealtimeTransportError.unavailable {
            state = .unavailable
            logger.info(.chat, "Realtime disabled; catch-up only")
        } catch {
            state = .disconnected
            logger.warning(.chat, "Chat connection failed: \(error)")
            scheduleReconnect(reason: "connect failed")
        }
        return false
    }

    /// A first connect takes the token as it is; every reconnect forces a refresh, or the same token would come back.
    private func token(fresh: Bool) async -> String? {
        guard let tokenProvider else { return nil }
        return fresh ? await tokenProvider.freshAccessToken() : await tokenProvider.accessToken()
    }

    /// Renews at `exp - reconnectBeforeExpiry` or at `maxConnectionAge`, whichever is first. A refreshed token whose
    /// `exp` is not later than the last one's, or a token already inside the renewal margin, would renew at once and
    /// loop: those waits fall into the backoff table instead (and never before the expiry-bound moment).
    func scheduleRenewal(for token: String?, fresh: Bool) {
        renewalTask?.cancel()
        let expiry = token.flatMap(JWTClaims.expiration)
        let untilExpiryBound = expiry.map { $0.timeIntervalSince(now()) - AppConfig.Realtime.reconnectBeforeExpiry }
        var delay = min(untilExpiryBound ?? AppConfig.Realtime.maxConnectionAge, AppConfig.Realtime.maxConnectionAge)
        if fresh, let expiry, let lastExpiry, expiry <= lastExpiry {
            delay = max(delay, nextBackoff())
            logger.warning(.chat, "Refreshed token expires no later than the last one; renewing in \(Int(delay))s")
        } else if let untilExpiryBound, untilExpiryBound <= 0 {
            delay = max(delay, nextBackoff())
            logger.warning(.chat, "Token is already inside the renewal margin; renewing in \(Int(delay))s")
        } else {
            backoffAttempt = 0
            logger.debug(.chat, "Chat connection renews in \(Int(delay))s")
        }
        lastExpiry = expiry ?? lastExpiry
        // The task lets go of its slot before reconnecting, or the close inside would cancel the very task doing it.
        renewalTask = Task { [weak self, sleep] in
            guard (try? await sleep(.seconds(max(delay, 0)))) != nil, let self else { return }
            renewalTask = nil
            await reconnect(reason: "token renewal")
        }
    }

    /// The connection dropped: back off, then reconnect with a fresh token.
    func scheduleReconnect(reason: String) {
        guard isActive, user != nil, reconnectTask == nil else { return }
        let delay = nextBackoff()
        logger.info(.chat, "Chat reconnecting in \(Int(delay))s (\(reason))")
        reconnectTask = Task { [weak self, sleep] in
            guard (try? await sleep(.seconds(delay))) != nil, let self else { return }
            reconnectTask = nil
            await reconnect(reason: reason)
        }
    }

    func reconnect(reason: String) async {
        await close(reason: reason)
        await connect(fresh: true)
    }

    /// Ends every subscription and the connection; the desire to be connected is untouched.
    func close(reason: String) async {
        connectionGeneration += 1
        renewalTask?.cancel()
        renewalTask = nil
        reconnectTask?.cancel()
        reconnectTask = nil
        subscriptions.values.forEach { $0.cancel() }
        subscriptions = [:]
        pendingResubscribes.values.forEach { $0.cancel() }
        pendingResubscribes = [:]
        subscribedRooms = [:]
        let wasOpen = state == .connected || state == .connecting
        if state != .unavailable { state = .disconnected }
        guard wasOpen else { return }
        await transport.disconnect()
        logger.info(.chat, "Chat connection closed (\(reason))")
    }

    /// Plan 4.5: subscribe first (done by the caller), then one Mine load, then catch up only the open room and the
    /// cached rooms whose newest message moved past their watermark, a few at a time.
    private func runResumeProtocol() async {
        await store.reload()
        guard state == .connected else { return }
        syncRooms()
        let openRoomID = openRoom?.groupID
        let limit = AppConfig.Chat.maxConcurrentCatchUps
        await catchUp.catchUpMovedRooms(store.groups, openRoomID: openRoomID, maxConcurrent: limit)
        let moved = adoptCachedEpochs()
        // Resubscribing at an epoch a page revealed reopens the gap the catch-up just closed, for those rooms only.
        guard !moved.isEmpty else { return }
        let movedGroups = store.groups.filter { moved.contains($0.id) }
        await catchUp.catchUpMovedRooms(movedGroups, openRoomID: openRoomID, maxConcurrent: limit)
    }

    /// A page that came back with a newer epoch than the one subscribed means a `member_left` was missed; answers the
    /// rooms that moved.
    func adoptCachedEpochs() -> Set<String> {
        var moved: Set<String> = []
        for (groupID, epoch) in subscribedRooms {
            if let fresh = cache.room(for: groupID)?.channelEpoch, fresh > epoch {
                logger.info(.chat, "Epoch changed for group \(groupID): \(epoch) -> \(fresh)")
                noteEpoch(fresh, for: groupID)
                moved.insert(groupID)
            }
        }
        reconcileSubscriptions()
        return moved
    }

    private func nextBackoff() -> TimeInterval {
        let table = AppConfig.Realtime.reconnectBackoffSeconds
        let base = table[min(backoffAttempt, table.count - 1)]
        backoffAttempt += 1
        return base * (1 + random(-AppConfig.Realtime.reconnectJitter...AppConfig.Realtime.reconnectJitter))
    }

    /// A refused token is the session's problem, not the socket's: said once, and no reconnect until the session changes.
    private func reportExpiredSessionOnce() {
        logger.warning(.chat, "Realtime connection refused the token")
        guard !reportedExpiredSession else { return }
        reportedExpiredSession = true
        // A REST call's 401 may be on screen already; one popup says it.
        guard errorCenter.current?.error != .sessionExpired else { return }
        errorCenter.report(AppError.sessionExpired)
    }
}
