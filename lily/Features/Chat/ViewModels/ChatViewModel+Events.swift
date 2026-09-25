import Foundation

/// What a message offers beyond its text: the game behind an `event_created` row (the wire carries only its id, so
/// the title is fetched once per screen), copying, and whether the caller may delete it.
extension ChatViewModel {
    /// "Marta created Sunday 5-a-side" once the game is known; "Marta created a game" until then, or when it is gone.
    func systemText(for message: ChatMessage) -> String {
        let title = message.eventId.flatMap { linkedEvents[$0]?.title } ?? AppBranding.Chat.eventCreatedFallbackTitle
        return AppBranding.Chat.eventCreated(by: message.senderName, title: title)
    }

    /// Fetches the game a system row points at so the row can name it; quiet when it cannot.
    func loadEvent(for message: ChatMessage) async {
        guard let eventID = message.eventId, linkedEvents[eventID] == nil else { return }
        if case .failure(let error) = await fetchEvent(id: eventID), !AppError.isCancellation(error) {
            logger.warning(.chat, "Event \(eventID) behind a system row in group \(group.id) is unavailable: \(error)")
        }
    }

    /// The game to open from a system row; a game that is gone or unreachable reaches the popup.
    func eventToOpen(for message: ChatMessage) async -> SportEvent? {
        guard let eventID = message.eventId else { return nil }
        switch await fetchEvent(id: eventID) {
        case .success(let event):
            return event
        case .failure(let error):
            report(error, during: "Opening the game behind a system row")
            return nil
        }
    }

    func copy(_ message: ChatMessage) {
        guard let text = message.text else { return }
        pasteboard.copy(text)
    }

    /// The sender and the group's admins may delete; a tombstone has nothing left to delete.
    func canDelete(_ message: ChatMessage) -> Bool {
        guard !message.isDeleted, !message.isSystem else { return false }
        return message.isSent(by: identity.currentUserID) || GroupAccess(group: group, userID: identity.currentUserID).canEdit
    }

    private func fetchEvent(id: String) async -> Result<SportEvent, any Error> {
        if let known = linkedEvents[id] { return .success(known) }
        do {
            let event = try await events.event(id: id)
            linkedEvents[id] = event
            return .success(event)
        } catch {
            return .failure(error)
        }
    }
}
