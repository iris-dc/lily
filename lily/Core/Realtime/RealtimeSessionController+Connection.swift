import Foundation

/// Opening, renewing, backing off and closing the connection, and the resume protocol that follows every open.
extension RealtimeSessionController {
    /// One connect at a time: a caller finding one in flight waits for it and then makes its own attempt (a no-op
    /// once connected), because the one it waited for may have been closed from under it. An attempt that a `close()`
    /// superseded while the app still wants a connection is followed by another, in a task of its own, since the
    /// superseded task is cancelled.
    func connect(fresh: Bool) async {
        var wantsAnotherAttempt = true
        while wantsAnotherAttempt {
            while let inFlight = connectionTask {
                _ = await inFlight.value
                if connectionTask == inFlight { connectionTask = nil }
            }
            let task = Task { await connectIfWanted(fresh: fresh) }
            connectionTask = task
            wantsAnotherAttempt = await task.value
            if connectionTask == task { connectionTask = nil }
        }
    }

    /// Connects when the app is active, a user is signed in and an endpoint is known; otherwise records why not.
    /// Answers whether a `close()` superseded the attempt while a connection is still wanted.
    private func connectIfWanted(fresh: Bool) async -> Bool {
        guard isActive, let user, state != .connected, state != .connecting else { return false }
        connectionGeneration += 1
        let generation = connectionGeneration
        guard let endpoint = await endpointProvider.endpoint() else {
            state = .unavailable
            logger.info(.chat, "Realtime disabled; catch-up only")
            return false
        }
        let token = await token(fresh: fresh)
        guard !isSuperseded(generation) else { return wantsConnection }
        if tokenProvider != nil, token == nil {
            noteMissingToken(fresh: fresh)
            return false
        }
        reconnectsWithoutToken = 0
        state = .connecting
        guard await open(endpoint, generation: generation) else { return false }
        guard !isSuperseded(generation), isActive else {
            // The socket opened for a connection that close() ended meanwhile; nobody else knows it exists, and this
            // task is the cancelled one, so the disconnect runs in its own.
            await Task { await transport.disconnect() }.value
            state = .disconnected
            return wantsConnection
        }
        state = .connected
        // A reconnect timer armed by an earlier failure is stale once a connect landed and would later tear this healthy
        // socket down (an .active <-> .inactive flip re-runs resume() while one is pending). The timer that ran this very
        // connect let go of its slot first, so it is never the one cancelled here.
        reconnectTask?.cancel()
        reconnectTask = nil
        logger.info(.chat, "Chat connection opened to \(endpoint.host() ?? endpoint.absoluteString)")
        scheduleRenewal(for: token, fresh: fresh)
        subscribe(to: .user(sub: user.id))
        reconcileSubscriptions()
        await runResumeProtocol()
        return false
    }

    /// `close()` cancels the connect in flight and moves the generation; either mark means the attempt is for a
    /// connection that no longer exists.
    private func isSuperseded(_ generation: Int) -> Bool {
        generation != connectionGeneration || Task.isCancelled
    }

    private var wantsConnection: Bool {
        isActive && user != nil
    }

    /// The transport's answer, sorted into what it means for the connection.
    private func open(_ endpoint: URL, generation: Int) async -> Bool {
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
            // The close() that superseded this attempt has its own follow-up; a timer here would double it.
            guard !isSuperseded(generation) else {
                logger.debug(.chat, "Chat connection attempt superseded (\(error))")
                return false
            }
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

    /// A forced refresh that answers no token is most often a network still down: the connection backs off along the
    /// table instead of staying dead until the next scene change, bounded by `maxReconnectsWithoutToken`. A first
    /// connect's missing token is the session's problem and arms nothing.
    private func noteMissingToken(fresh: Bool) {
        logger.warning(.chat, "No access token for the realtime connection; staying disconnected")
        guard fresh else { return }
        reconnectsWithoutToken += 1
        let bound = AppConfig.Realtime.maxReconnectsWithoutToken
        guard reconnectsWithoutToken <= bound else {
            logger.warning(.chat, "No access token after \(bound) reconnects; waiting for the next foreground")
            return
        }
        scheduleReconnect(reason: "no token")
    }

    /// Renews at the moment `RenewalDelay` decides: the expiry-bound one for a good token, after a backoff wait otherwise.
    func scheduleRenewal(for token: String?, fresh: Bool) {
        renewalTask?.cancel()
        let expiry = token.flatMap(JWTClaims.expiration)
        let renewal = RenewalDelay(expiry: expiry, lastExpiry: lastExpiry, now: now(), fresh: fresh)
        let delay = renewal.seconds(backingOff: &backoff, random: random)
        switch renewal.reason {
        case .staleToken:
            logger.warning(.chat, "Refreshed token expires no later than the last one; renewing in \(Int(delay))s")
        case .insideMargin:
            logger.warning(.chat, "Token is already inside the renewal margin; renewing in \(Int(delay))s")
        case .scheduled:
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
        let delay = backoff.next(random: random)
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

    /// Ends every subscription and the connection, and the connect in flight if there is one; the desire to be
    /// connected is untouched.
    func close(reason: String) async {
        connectionGeneration += 1
        connectionTask?.cancel()
        renewalTask?.cancel()
        renewalTask = nil
        reconnectTask?.cancel()
        reconnectTask = nil
        subscriptions.values.forEach { $0.task.cancel() }
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

    /// The resume protocol: subscribe first (done by the caller), then one Mine load, then catch up only the open room
    /// and the cached rooms whose newest message moved past their watermark, a few at a time.
    private func runResumeProtocol() async {
        await store.reload()
        guard state == .connected else { return }
        syncRooms()
        let openRoomID = openRoom?.groupID
        let limit = AppConfig.Chat.maxConcurrentCatchUps
        await catchUp.catchUpMovedRooms(store.groups, openRoomID: openRoomID, maxConcurrent: limit)
        let moved = adoptCachedEpochs()
        // Resubscribing at an epoch a page revealed reopens the gap the catch-up just closed, for those rooms only;
        // their watermarks say nothing new, so this pass names them outright.
        guard !moved.isEmpty else { return }
        await catchUp.catchUpRooms(moved.sorted(), maxConcurrent: limit)
    }

    /// The resume protocol did not run because there is no connection to run it after: the open chat's room still
    /// catches up, quietly, and the epoch its page answered is remembered for the next connect. A suspend that landed
    /// during the resume protocol leaves nobody to show the page, so a backgrounded app fetches nothing here.
    func catchUpOpenRoomWithoutConnection() async {
        guard isActive, state != .connected, let openRoom else { return }
        logger.info(.chat, "No connection; catching up the open room \(openRoom.groupID) over REST")
        await catchUp.catchUpRooms([openRoom.groupID], maxConcurrent: 1)
        if let epoch = cache.room(for: openRoom.groupID)?.channelEpoch { noteEpoch(epoch, for: openRoom.groupID) }
    }

    /// A page that came back with a newer epoch than the one subscribed means a `member_left` was missed; answers the
    /// rooms that moved.
    func adoptCachedEpochs() -> Set<String> {
        var moved: Set<String> = []
        for groupID in subscribedRooms.keys {
            if let fresh = cache.room(for: groupID)?.channelEpoch, moveEpoch(of: groupID, to: fresh) {
                moved.insert(groupID)
            }
        }
        reconcileSubscriptions()
        return moved
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
