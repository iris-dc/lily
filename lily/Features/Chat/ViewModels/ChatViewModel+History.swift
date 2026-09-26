import Foundation

/// The room's history: the first page or the catch-up on appear, the page before as the reader scrolls up, and the
/// epoch every group-scoped answer carries.
extension ChatViewModel {
    func loadHistory() async {
        isLoadingHistory = true
        defer { isLoadingHistory = false }
        do {
            if room.hasHistory {
                try await catchUp.catchUp(groupID: group.id)
            } else {
                try await catchUp.loadNewest(groupID: group.id, epoch: group.channelEpoch)
            }
            await adoptEpoch(room.channelEpoch)
        } catch {
            report(error, during: "Loading messages")
        }
    }

    /// The page before the oldest message held, or before the cursor the last backward page named. Answers whether a
    /// message not held before arrived, which is what tells the transcript a taller layout is coming: the first row
    /// is a day chip, so a same-day prepend keeps the first row's id and cannot be judged from the rows.
    @discardableResult
    func loadOlder() async -> Bool {
        guard hasOlder, !isLoadingOlder, let anchor = room.olderPageAnchor else { return false }
        let oldest = room.oldestID
        isLoadingOlder = true
        defer { isLoadingOlder = false }
        do {
            let page = try await repository.older(groupID: group.id, before: anchor)
            guard let updated = mutateRoom({ $0.applyOlder(page) }) else { return false }
            await adoptEpoch(page.channelEpoch)
            return updated.oldestID != oldest
        } catch {
            report(error, during: "Loading older messages")
            return false
        }
    }

    /// Any group-scoped answer or event carrying a newer epoch: resubscribe there, then catch up what the gap hid.
    func adoptEpoch(_ epoch: Int) async {
        guard epoch > subscribedEpoch else { return }
        logger.info(.chat, "Epoch changed for group \(group.id): \(subscribedEpoch) -> \(epoch)")
        subscribedEpoch = epoch
        mutateRoom { $0.noteEpoch(epoch) }
        let subscription = RoomSubscription(groupID: group.id, epoch: epoch)
        if liveTask != nil { realtime.setOpenRoom(subscription) }
        await realtime.ensureSubscribed(subscription)
        do {
            try await catchUp.catchUp(groupID: group.id)
        } catch {
            guard !AppError.isCancellation(error) else { return }
            logger.warning(.chat, "Catch-up after an epoch change failed for group \(group.id): \(error)")
        }
    }
}
