import Foundation

/// Subscriptions and what arrives on them: the room cache and the unread set are updated here, epochs are followed
/// (a `member_left` is trusted and resubscribed with jitter; the group is refetched only when a subscribe is refused),
/// and every room envelope is handed to the listeners of its room; the user channel feeds the stores alone.
extension RealtimeSessionController {
    /// Brings the live subscriptions in line with `desiredRooms()`; a no-op while not connected.
    func reconcileSubscriptions() {
        guard state == .connected else { return }
        let desired = desiredRooms()
        for (groupID, epoch) in subscribedRooms where desired[groupID] == nil {
            unsubscribe(groupID: groupID, epoch: epoch)
            logger.debug(.chat, "Unsubscribed from \(RealtimeChannel.room(groupID: groupID, epoch: epoch).path)")
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
        let id = UUID()
        subscriptions[channel] = Subscription(id: id, task: Task { [weak self] in
            do {
                for try await envelope in stream {
                    guard let self else { return }
                    route(envelope, from: channel)
                }
                await self?.streamEnded(channel, id: id, error: nil)
            } catch {
                await self?.streamEnded(channel, id: id, error: error)
            }
        })
    }

    private func unsubscribe(groupID: String, epoch: Int) {
        let channel = RealtimeChannel.room(groupID: groupID, epoch: epoch)
        subscriptions[channel]?.task.cancel()
        subscriptions[channel] = nil
        if subscribedRooms[groupID] == epoch { subscribedRooms[groupID] = nil }
    }

    /// A stream that ended on its own (not cancelled by us) either was refused or lost its connection. Only the stream
    /// still held for the channel counts: a cancelled predecessor on the same channel ends under its own id, and
    /// `close()` empties the map before any later connection subscribes.
    private func streamEnded(_ channel: RealtimeChannel, id: UUID, error: (any Error)?) async {
        guard subscriptions[channel]?.id == id else { return }
        subscriptions[channel] = nil
        if case .room(let groupID, let epoch) = channel, subscribedRooms[groupID] == epoch {
            subscribedRooms[groupID] = nil
        }
        guard (error as? RealtimeTransportError) == .subscribeRefused else {
            // Only the first stream to end logs: the close clears every other subscription before it can.
            let cause = error.map { String(describing: $0) } ?? "finished"
            logger.warning(.chat, "Stream ended on \(channel.path): \(cause)")
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
            moveEpoch(of: groupID, to: group.channelEpoch)
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
        case .room(let groupID, let epoch):
            guard envelope.groupID == nil || envelope.groupID == groupID else {
                logger.warning(.chat, "Dropped an envelope of another group (\(envelope.groupID ?? "?")) on \(channel.path)")
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
            applyMemberLeft(userID: userID, groupID: groupID, epoch: epoch, memberCount: memberCount)
        case .groupDeleted:
            removeGroupLocally(groupID, reason: "group deleted")
        case .groupUpdated(let group):
            store.apply(group)
            adoptEpoch(envelope.channelEpoch, for: groupID)
        case .memberJoined:
            adoptEpoch(envelope.channelEpoch, for: groupID)
        case .tournamentChanged, .matchUpdated:
            // The tournament screens refetch the detail; a change's epoch is the room's new one.
            tournamentChanges.recordChange()
            adoptEpoch(envelope.channelEpoch, for: groupID)
        case .membershipChanged, .inboxItem:
            // Both belong to the user channel; on a room they say nothing about the room.
            let channel = RealtimeChannel.room(groupID: groupID, epoch: subscribedEpoch)
            logger.debug(.chat, "Ignored a user-channel event on \(channel.path)")
        case .unknown(let type):
            let channel = RealtimeChannel.room(groupID: groupID, epoch: subscribedEpoch)
            logger.debug(.chat, "Ignored a \(type) event on \(channel.path)")
        }
    }

    /// The caller's own departure drops the room; anyone else's moves the epoch, which is followed with jitter.
    private func applyMemberLeft(userID: String, groupID: String, epoch: Int, memberCount: Int) {
        if userID == identity.currentUserID {
            removeGroupLocally(groupID, reason: "removed from group")
        } else {
            resubscribeJittered(groupID, to: epoch, memberCount: memberCount)
        }
    }

    /// Into the cache; a room that is not open also gets its unread dot and, since only the open chat pages through a
    /// room, keeps just the cache's newest rows.
    private func applyMessage(_ message: ChatMessage, groupID: String) {
        cache.update(groupID: groupID) { $0.insert(message) }
        // A room not cached never reaches the cache's own note.
        store.noteMessage(message, in: groupID)
        guard openRoom?.groupID != groupID else { return }
        cache.compact(groupID: groupID)
        if !message.isSent(by: identity.currentUserID) { unread.markUnread(groupID: groupID, messageID: message.id) }
    }

    /// `users/<sub>`: the caller's own membership moved (Mine is stale, and a membership that ended takes the room
    /// with it), or an invite or reminder arrived for their inbox.
    private func applyUserEvent(_ envelope: RealtimeEnvelope) {
        switch envelope {
        case .membershipChanged(let change):
            applyMembershipChange(change)
        case .inboxItem(let item):
            inbox.apply(item)
        default:
            return
        }
    }

    private func applyMembershipChange(_ change: MembershipChange) {
        if change.endsMembership {
            removeGroupLocally(change.groupId, reason: "membership \(change.change.rawValue)")
        } else {
            logger.info(.chat, "Membership \(change.change.rawValue) for group \(change.groupId)")
            noteEpoch(change.channelEpoch, for: change.groupId)
            groupChanges.recordChange()
            reconcileSubscriptions()
        }
    }

    /// The epoch a response or an event carries, when it is newer than anything known: resubscribe at once.
    private func adoptEpoch(_ epoch: Int?, for groupID: String) {
        if moveEpoch(of: groupID, to: epoch) { reconcileSubscriptions() }
    }

    /// Notes an epoch learned from any source (an event, a page, a refetched group, the open chat's send) for the cached
    /// room and for the controller, each when newer than what it holds. Answers whether the controller's knowledge
    /// moved; the caller decides whether to resubscribe at once or with jitter.
    @discardableResult
    func moveEpoch(of groupID: String, to epoch: Int?) -> Bool {
        guard let epoch else { return false }
        if let cached = cache.room(for: groupID)?.channelEpoch, epoch > cached {
            cache.update(groupID: groupID) { $0.noteEpoch(epoch) }
        }
        let known = knownEpochs[groupID] ?? 0
        guard epoch > known else { return false }
        logger.info(.chat, "Epoch changed for group \(groupID): \(known) -> \(epoch)")
        noteEpoch(epoch, for: groupID)
        return true
    }

    /// `member_left` is trusted (a wrong epoch is refused by the backend anyway), and the resubscribe is spread over
    /// `min(memberCount x resubscribeJitterPerMember, resubscribeJitterMax)` so a large room does not herd.
    private func resubscribeJittered(_ groupID: String, to epoch: Int, memberCount: Int) {
        guard moveEpoch(of: groupID, to: epoch) else { return }
        let timing = AppConfig.Realtime.self
        let delay = random(0...min(Double(memberCount) * timing.resubscribeJitterPerMember, timing.resubscribeJitterMax))
        // One decimal, not Int(delay): a sub-second jitter would print as 0.
        logger.debug(.chat, "Resubscribing to group \(groupID) at epoch \(epoch) in \(String(format: "%.1f", delay))s")
        pendingResubscribes[groupID]?.cancel()
        pendingResubscribes[groupID] = Task { [weak self, sleep] in
            guard (try? await sleep(.seconds(delay))) != nil, let self else { return }
            pendingResubscribes[groupID] = nil
            reconcileSubscriptions()
        }
    }

    /// The caller is out of the group, whichever way (an event, a page or write refused with `NOT_A_MEMBER` or
    /// `GROUP_NOT_FOUND`, a conversation they hid): Mine (which records the change for every other screen), the room
    /// cache, the unread dot and the subscription go.
    func removeGroupLocally(_ groupID: String, reason: String) {
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

    private func deliver(_ envelope: RealtimeEnvelope, to groupID: String) {
        consumers.values.filter { $0.groupID == groupID }.forEach { $0.continuation.yield(envelope) }
    }
}
