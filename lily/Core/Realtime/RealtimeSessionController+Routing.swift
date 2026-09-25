import Foundation

/// Subscriptions and what arrives on them: the room cache and the unread set are updated here, epochs are followed
/// (a `member_left` is trusted and resubscribed with jitter; the group is refetched only when a subscribe is refused),
/// and every envelope is handed to the listeners of its room or of the user channel.
extension RealtimeSessionController {
    /// Brings the live subscriptions in line with `desiredRooms()`; a no-op while not connected.
    func reconcileSubscriptions() {
        guard state == .connected else { return }
        let desired = desiredRooms()
        for (groupID, epoch) in subscribedRooms where desired[groupID] == nil {
            unsubscribe(groupID: groupID, epoch: epoch)
        }
        // A room whose jittered resubscribe is pending keeps its old subscription until that task runs.
        for (groupID, epoch) in desired
        where subscribedRooms[groupID] != epoch && pendingResubscribes[groupID] == nil {
            if let stale = subscribedRooms[groupID] { unsubscribe(groupID: groupID, epoch: stale) }
            subscribedRooms[groupID] = epoch
            subscribe(to: .room(groupID: groupID, epoch: epoch))
            logger.info(.chat, "Subscribed to \(RealtimeChannel.room(groupID: groupID, epoch: epoch).path)")
        }
    }

    func subscribe(to channel: RealtimeChannel) {
        let stream = transport.subscribe(to: channel)
        let generation = connectionGeneration
        subscriptions[channel] = Task { [weak self] in
            do {
                for try await envelope in stream {
                    guard let self else { return }
                    route(envelope, from: channel)
                }
                await self?.streamEnded(channel, error: nil, generation: generation)
            } catch {
                await self?.streamEnded(channel, error: error, generation: generation)
            }
        }
    }

    private func unsubscribe(groupID: String, epoch: Int) {
        let channel = RealtimeChannel.room(groupID: groupID, epoch: epoch)
        subscriptions[channel]?.cancel()
        subscriptions[channel] = nil
        if subscribedRooms[groupID] == epoch { subscribedRooms[groupID] = nil }
    }

    /// A stream that ended on its own (not cancelled by us) either was refused or lost its connection.
    private func streamEnded(_ channel: RealtimeChannel, error: (any Error)?, generation: Int) async {
        guard generation == connectionGeneration, subscriptions[channel] != nil else { return }
        subscriptions[channel] = nil
        if case .room(let groupID, let epoch) = channel, subscribedRooms[groupID] == epoch {
            subscribedRooms[groupID] = nil
        }
        guard (error as? RealtimeTransportError) == .subscribeRefused else {
            await close(reason: "connection lost")
            scheduleReconnect(reason: "connection lost")
            return
        }
        guard case .room(let groupID, let refusedEpoch) = channel else {
            logger.warning(.chat, "The user channel was refused")
            return
        }
        await refetchAndResubscribe(groupID, refusedEpoch: refusedEpoch)
    }

    /// Only a refused subscribe costs a group read: the epoch it carries is the one to subscribe to. An epoch no newer
    /// than the refused one would be refused again, so the room waits for the next sync instead of looping.
    private func refetchAndResubscribe(_ groupID: String, refusedEpoch: Int) async {
        do {
            let group = try await groupRepository.group(id: groupID)
            guard group.isMember, !group.isDeleted else {
                removeGroupLocally(groupID, reason: "no longer a member")
                return
            }
            store.replace(group)
            guard group.channelEpoch > refusedEpoch else {
                logger.warning(.chat, "Subscribe refused for group \(groupID) at the current epoch \(refusedEpoch); not retrying")
                return
            }
            logger.info(.chat, "Epoch changed for group \(groupID): \(refusedEpoch) -> \(group.channelEpoch)")
            noteEpoch(group.channelEpoch, for: groupID)
            reconcileSubscriptions()
            // The room was unsubscribed between the refusal and now; the server alone has what was published meanwhile.
            await catchUp.catchUpMovedRooms([group], openRoomID: openRoom?.groupID, maxConcurrent: 1)
        } catch AppError.groupNotFound {
            removeGroupLocally(groupID, reason: "group not found")
        } catch {
            logger.warning(.chat, "Could not refetch group \(groupID) after a refused subscribe: \(error)")
        }
    }

    private func route(_ envelope: RealtimeEnvelope, from channel: RealtimeChannel) {
        switch channel {
        case .user:
            applyUserEvent(envelope)
            deliver(envelope, to: nil)
        case .room(let groupID, let epoch):
            guard envelope.groupID == nil || envelope.groupID == groupID else {
                logger.warning(.chat, "Dropped an envelope for another group on \(channel.path)")
                return
            }
            applyRoomEvent(envelope, groupID: groupID, subscribedEpoch: epoch)
            deliver(envelope, to: groupID)
        }
    }

    private func applyRoomEvent(_ envelope: RealtimeEnvelope, groupID: String, subscribedEpoch: Int) {
        switch envelope {
        case .message(let message):
            applyMessage(message, groupID: groupID)
        case .messageDeleted(_, let id):
            cache.update(groupID: groupID) { $0.markDeleted(id: id) }
        case .memberLeft(_, let userID, let epoch, let memberCount):
            if userID == identity.currentUserID {
                removeGroupLocally(groupID, reason: "removed from group")
            } else {
                resubscribeJittered(groupID, to: epoch, from: subscribedEpoch, memberCount: memberCount)
            }
        case .groupDeleted:
            removeGroupLocally(groupID, reason: "group deleted")
        case .groupUpdated(let group):
            store.apply(group)
            adoptEpoch(envelope.channelEpoch, for: groupID, from: subscribedEpoch)
        case .memberJoined:
            adoptEpoch(envelope.channelEpoch, for: groupID, from: subscribedEpoch)
        case .membershipChanged:
            let channel = RealtimeChannel.room(groupID: groupID, epoch: subscribedEpoch)
            logger.debug(.chat, "Ignored a membership change on \(channel.path)")
        case .unknown(let type):
            let channel = RealtimeChannel.room(groupID: groupID, epoch: subscribedEpoch)
            logger.debug(.chat, "Ignored a \(type) event on \(channel.path)")
        }
    }

    /// Into the cache; a room that is not open also gets its unread dot and, since only the open chat pages through a
    /// room, keeps just the cache's newest rows.
    private func applyMessage(_ message: ChatMessage, groupID: String) {
        cache.update(groupID: groupID) { $0.insert(message) }
        guard openRoom?.groupID != groupID else { return }
        cache.compact(groupID: groupID)
        if !message.isSent(by: identity.currentUserID) { unread.markUnread(groupID: groupID) }
    }

    /// `users/<sub>`: the caller's own membership moved; Mine is stale, and a membership that ended takes the room with it.
    private func applyUserEvent(_ envelope: RealtimeEnvelope) {
        guard case .membershipChanged(let change) = envelope else { return }
        if change.endsMembership {
            removeGroupLocally(change.groupId, reason: "membership \(change.change.rawValue)")
        } else {
            noteEpoch(change.channelEpoch, for: change.groupId)
            groupChanges.recordChange()
            reconcileSubscriptions()
        }
    }

    /// The epoch a response or an event carries, when it is newer than the one subscribed: resubscribe at once.
    private func adoptEpoch(_ epoch: Int?, for groupID: String, from subscribedEpoch: Int) {
        guard let epoch, epoch > subscribedEpoch else { return }
        logger.info(.chat, "Epoch changed for group \(groupID): \(subscribedEpoch) -> \(epoch)")
        noteEpoch(epoch, for: groupID)
        cache.update(groupID: groupID) { $0.noteEpoch(epoch) }
        reconcileSubscriptions()
    }

    /// `member_left` is trusted (a wrong epoch is refused by the backend anyway), and the resubscribe is spread over
    /// `min(memberCount x resubscribeJitterPerMember, resubscribeJitterMax)` so a large room does not herd.
    private func resubscribeJittered(_ groupID: String, to epoch: Int, from subscribedEpoch: Int, memberCount: Int) {
        guard epoch > subscribedEpoch, epoch > (knownEpochs[groupID] ?? 0) else { return }
        logger.info(.chat, "Epoch changed for group \(groupID): \(subscribedEpoch) -> \(epoch)")
        noteEpoch(epoch, for: groupID)
        cache.update(groupID: groupID) { $0.noteEpoch(epoch) }
        let timing = AppConfig.Realtime.self
        let delay = random(0...min(Double(memberCount) * timing.resubscribeJitterPerMember, timing.resubscribeJitterMax))
        pendingResubscribes[groupID]?.cancel()
        pendingResubscribes[groupID] = Task { [weak self, sleep] in
            guard (try? await sleep(.seconds(delay))) != nil, let self else { return }
            pendingResubscribes[groupID] = nil
            reconcileSubscriptions()
        }
    }

    /// The caller is out of the group, whichever way: Mine (which records the change for every other screen), the
    /// room cache, the unread dot and the subscription go.
    private func removeGroupLocally(_ groupID: String, reason: String) {
        store.remove(id: groupID)
        cache.drop(groupID: groupID, reason: reason)
        unread.markRead(groupID: groupID)
        knownEpochs[groupID] = nil
        wantedRooms.removeAll { $0.groupID == groupID }
        if openRoom?.groupID == groupID { openRoom = nil }
        pendingResubscribes[groupID]?.cancel()
        pendingResubscribes[groupID] = nil
        if let epoch = subscribedRooms[groupID] { unsubscribe(groupID: groupID, epoch: epoch) }
        logger.info(.chat, "Group \(groupID) dropped (\(reason))")
    }

    private func deliver(_ envelope: RealtimeEnvelope, to groupID: String?) {
        consumers.values.filter { $0.groupID == groupID }.forEach { $0.continuation.yield(envelope) }
    }
}
