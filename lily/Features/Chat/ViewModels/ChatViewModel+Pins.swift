import Foundation

/// Pinned messages: the room's pins as the latest page or answer listed them, minus messages this device knows are
/// deleted, and pinning or unpinning a message. The answer replaces the pins; a catch-up after a pin brings the
/// backend's note ("… pinned «…»") into the chat.
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
        let changed = await changePins(of: message.id, during: "Pinning") {
            try await repository.pin(groupID: group.id, messageID: message.id)
        }
        guard changed else { return }
        logger.info(.chat, "Message \(message.id) pinned in group \(group.id)")
        do {
            try await catchUp.catchUp(groupID: group.id)
        } catch {
            logger.warning(.chat, "Catch-up after a pin failed in group \(group.id): \(error)")
        }
    }

    func unpin(_ messageID: String) async {
        let changed = await changePins(of: messageID, during: "Unpinning") {
            try await repository.unpin(groupID: group.id, messageID: messageID)
        }
        if changed { logger.info(.chat, "Message \(messageID) unpinned in group \(group.id)") }
    }

    /// Whether the backend answered; a refusal reached the popup and changed nothing.
    private func changePins(of messageID: String, during step: String, _ work: () async throws -> PinList) async -> Bool {
        do {
            let list = try await LostRace.attemptTwice(delay: tryAgainDelay,
                                                       logger: logger,
                                                       category: .chat,
                                                       retrying: "\(step) in group \(group.id)",
                                                       work)
            mutateRoom { $0.applyPins(list.pins) }
            await adoptEpoch(list.channelEpoch)
            return true
        } catch {
            report(error, during: "\(step) message \(messageID)")
            return false
        }
    }
}
