import Foundation

/// Pinned messages: the room's pins as the latest page or answer listed them, minus messages this device knows are
/// deleted, and pinning or unpinning a message. The answer replaces the pins; a catch-up after a pin brings the
/// backend's note ("… pinned «…»") into the chat. A lost answer is read back through one catch-up (`LostAnswer`): every
/// page carries the pins, so the bar shows the backend's and the popup only comes when they do not show the intent.
extension ChatViewModel {
    /// Oldest first, as the backend lists them; the bar shows the newest.
    var pins: [PinnedMessage] {
        room.pins.filter { !room.isDeleted(id: $0.messageId) }
    }

    /// Whether the caller pins and unpins here: the long press's Pin and Unpin, the bar's ✕.
    var canChangePins: Bool {
        GroupAccess(group: group, userID: identity.currentUserID).canPin(in: group)
    }

    func canPin(_ message: ChatMessage) -> Bool {
        !message.isDeleted && !message.isSystem && canChangePins
    }

    /// What the long press offers: Pin, Unpin, or neither.
    func pinning(of message: ChatMessage) -> MessageMenuItems.Pinning {
        guard canPin(message) else { return .none }
        return isPinned(message.id) ? .unpin : .pin
    }

    func isPinned(_ messageID: String) -> Bool {
        room.pins.contains { $0.messageId == messageID }
    }

    func pin(_ message: ChatMessage) async {
        guard canPin(message) else { return }
        let changed = await changePins(of: message.id, wanting: true, during: "Pinning") {
            try await repository.pin(groupID: group.id, messageID: message.id)
        }
        if changed { logger.info(.chat, "Message \(message.id) pinned in group \(group.id)") }
    }

    func unpin(_ messageID: String) async {
        let changed = await changePins(of: messageID, wanting: false, during: "Unpinning") {
            try await repository.unpin(groupID: group.id, messageID: messageID)
        }
        if changed { logger.info(.chat, "Message \(messageID) unpinned in group \(group.id)") }
    }

    /// Whether the pins now show `pinned` for the message, by the answer or by the read-back after a lost one; a refusal
    /// reached the popup and changed nothing. A pin that answered catches up for the backend's note; one settled by the
    /// read-back has caught up already. The read-back judges the room the catch-up answered, never `room`, whose stub
    /// for a dropped room has no pins and would pass an unpin as landed.
    private func changePins(of messageID: String,
                            wanting pinned: Bool,
                            during step: String,
                            _ work: () async throws -> PinList) async -> Bool {
        do {
            let list = try await LostRace.attemptTwice(delay: tryAgainDelay,
                                                       logger: logger,
                                                       category: .chat,
                                                       retrying: "\(step) in group \(group.id)",
                                                       work)
            mutateRoom { $0.applyPins(list.pins) }
            await adoptEpoch(list.channelEpoch)
            if pinned { await catchUpForNote() }
            return true
        } catch {
            let settled = await pinReadBack.settle("\(step) message \(messageID)", despite: error) { state in
                state.map { fresh in fresh.pins.contains { $0.messageId == messageID } == pinned }
            }
            guard !settled.isLanded else { return true }
            report(error, during: "\(step) message \(messageID)")
            return false
        }
    }

    /// The catch-up writes the cache itself, so there is nothing to apply.
    private var pinReadBack: LostAnswer<ChatRoomState?> {
        LostAnswer(category: .chat,
                   logger: logger,
                   leavesOutcomeUnknown: { $0.leavesPinOutcomeUnknown },
                   refetch: { [self] in try await catchUp.catchUp(groupID: group.id) },
                   apply: { _ in })
    }

    private func catchUpForNote() async {
        do {
            try await catchUp.catchUp(groupID: group.id)
        } catch {
            logger.warning(.chat, "Catch-up after a pin failed in group \(group.id): \(error)")
        }
    }
}
