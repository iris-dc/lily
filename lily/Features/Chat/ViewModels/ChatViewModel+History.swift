import Foundation

/// The room's history: the first page or the catch-up on appear, the page before as the reader scrolls up, and the
/// epoch every group-scoped answer carries.
extension ChatViewModel {
    /// The first page for a room not cached yet, or a catch-up from the watermark for one that is. A failure that
    /// leaves the room the caller's sets `historyLoadFailed`, so the empty state offers Try again, which runs this
    /// alone: `appear()` already started the live task, the marker and the roster after the failed page.
    func loadHistory() async {
        isLoadingHistory = true
        historyLoadFailed = false
        defer { isLoadingHistory = false }
        do {
            if room.hasHistory {
                logger.debug(.cache, "Room cache hit for group \(group.id); catching up from the watermark")
                try await catchUp.catchUp(groupID: group.id)
            } else {
                logger.debug(.cache, "Room cache miss for group \(group.id); loading the newest page")
                try await catchUp.loadNewest(groupID: group.id, epoch: group.channelEpoch)
            }
            await adoptEpoch(room.channelEpoch)
        } catch {
            historyLoadFailed = Self.leavesRoomReadable(error)
            report(error, during: "Loading messages")
        }
    }

    /// Whether a history failure leaves the room the caller's to read, so Try again is worth offering: not a
    /// cancellation (the screen left) and not a page that ended the room's access (`report` drops that room).
    private static func leavesRoomReadable(_ error: any Error) -> Bool {
        !AppError.isCancellation(error) && !((error as? AppError)?.endsRoomAccess ?? false)
    }

    var isLoadingOlder: Bool { olderPageTask != nil }

    /// The oldest message held, which the transcript compares across an older-page request to tell the prepend from
    /// growth at the bottom.
    var oldestID: String? { room.oldestID }

    /// The page before the oldest message held, or before the cursor the last backward page named. Answers whether a
    /// message not held before arrived, which is what tells the transcript a taller layout is coming: the first row
    /// is a day chip, so a same-day prepend keeps the first row's id and cannot be judged from the rows. One page is
    /// in flight at a time: this answers `false` while one is, and a caller that needs that page waits for
    /// `olderPageTask` instead (`revealQuoted`).
    @discardableResult
    func loadOlder() async -> Bool {
        guard hasOlder, olderPageTask == nil, let anchor = room.olderPageAnchor else { return false }
        // The slot is let go inside the task, so every waiter resuming on its value already finds it empty.
        let task = Task { [self] in
            defer { olderPageTask = nil }
            return await fetchOlderPage(before: anchor)
        }
        olderPageTask = task
        return await task.value
    }

    /// The request for the page before `anchor` and its application; `false` when the page was refused because the
    /// room moved or left the cache meanwhile, when nothing new arrived, and when the request failed.
    private func fetchOlderPage(before anchor: String) async -> Bool {
        let oldest = room.oldestID
        do {
            let page = try await repository.older(groupID: group.id, before: anchor)
            var applied = false
            guard let updated = mutateRoom({ applied = $0.applyOlder(page, before: anchor) }), applied else {
                logger.debug(.chat, "Older page before \(anchor) dropped in group \(group.id): the room moved meanwhile")
                return false
            }
            await adoptEpoch(page.channelEpoch)
            return updated.oldestID != oldest
        } catch {
            report(error, during: "Loading older messages")
            return false
        }
    }

    /// Any group-scoped answer or event carrying an epoch newer than the one this screen subscribed: the controller
    /// notes it for the cached room and, when it is news to it too, logs it once (a `member_left` it handled first
    /// is not logged twice); then resubscribe there and catch up what the gap hid.
    func adoptEpoch(_ epoch: Int) async {
        guard epoch > subscribedEpoch else { return }
        realtime.moveEpoch(of: group.id, to: epoch)
        subscribedEpoch = epoch
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
