import Foundation

/// What arrives live for the open room. Messages are already in the cache when they get here (the controller puts
/// them there); this side settles optimistic bubbles, follows epoch changes and notices when the room is gone.
extension ChatViewModel {
    func startLive() {
        guard !Task.isCancelled else { return }
        liveTask?.cancel()
        let stream = realtime.envelopes(for: group.id)
        liveTask = Task { [weak self] in
            for await envelope in stream {
                guard let self, !Task.isCancelled else { return }
                await handle(envelope)
            }
        }
    }

    func handle(_ envelope: RealtimeEnvelope) async {
        switch envelope {
        case .message(let message):
            if let clientMessageID = message.clientMessageId, message.isSent(by: identity.currentUserID) {
                seedAttachmentCache(for: clientMessageID, with: message)
                pending.removeAll { $0.clientMessageID == clientMessageID }
            }
            // A game announced here was created elsewhere; the group's Events segment behind this screen must reload.
            if message.kind == .eventCreated { eventChanges.recordChange() }
            noteRead()
        case .memberJoined(_, _, let memberCount, let epoch):
            group = group.updatingMembership(group.membership, memberCount: memberCount, channelEpoch: epoch)
            await adoptEpoch(epoch)
        case .memberLeft(_, let userID, let epoch, let memberCount):
            guard userID != identity.currentUserID else {
                isGone = true
                return
            }
            group = group.updatingMembership(group.membership, memberCount: memberCount, channelEpoch: epoch)
            await adoptEpoch(epoch)
        case .groupUpdated(let updated):
            group = updated.keepingMembership(of: group)
            await adoptEpoch(updated.channelEpoch)
        case .groupDeleted:
            isGone = true
        case .messageDeleted, .membershipChanged, .inboxItem, .unknown:
            break
        }
    }
}
