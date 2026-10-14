import Foundation

/// The system rows' facade for `SystemMessageRow`, over `systemRows`; a game that cannot be opened reaches the popup
/// from here. Copying and whether the caller may delete a message are the room's own.
extension ChatViewModel {
    func systemText(for message: ChatMessage) -> String {
        systemRows.text(for: message)
    }

    func loadLinkedContent(for message: ChatMessage) async {
        await systemRows.load(for: message)
    }

    /// Where the row leads; a game that is gone or unreachable reaches the popup and answers `nil`.
    func destination(for message: ChatMessage) async -> SystemRowDestination? {
        switch await systemRows.destination(for: message, roomName: group.name) {
        case .success(let destination):
            return destination
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
}
