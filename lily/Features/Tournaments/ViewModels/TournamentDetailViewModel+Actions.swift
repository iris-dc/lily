import Foundation

/// The actions that write no entry and no match, shared by the menu and the in-body action row: opening the room's
/// chat and the organiser's cancel. Out of the main file, which is at the type-body limit.
extension TournamentDetailViewModel {
    /// The room is a group under the tournament's id; fetched for the chat, which needs the group as the backend holds it.
    /// Placed in Mine first, as an accepted invite's is: Mine's by-user index may still miss a room just entered, and
    /// the Chats tab and split view list only rooms Mine holds. The chat is pushed on the detail's own stack
    /// (`openedRoom`), so Back returns to the tournament rather than landing on the Chats list, like a profile's
    /// "Message".
    func openChat() async {
        guard permissions.canOpenChat else { return }
        await perform("Open chat") { [self] in
            let room = try await groupRepository.group(id: destination.id)
            if room.isMember { myGroups.add(room) }
            openedRoom = room
        }
    }

    /// The organiser calls it off; the room stays, the lists learn of it.
    func cancel() async {
        await perform("Cancel") { [self] in
            let cancelled = try await repository.cancel(id: destination.id)
            accept(cancelled)
            logger.info(.tournaments, "Tournament \(cancelled.id) cancelled")
        }
    }
}
