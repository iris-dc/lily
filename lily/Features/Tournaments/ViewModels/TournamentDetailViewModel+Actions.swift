import Foundation

/// The detail menu's actions that write no entry and no match: opening the room's chat and the organiser's cancel. Out
/// of the main file, which is at the type-body limit.
extension TournamentDetailViewModel {
    /// The room is a group under the tournament's id; fetched for the chat, which needs the group as the backend holds it.
    /// Placed in Mine first, as an accepted invite's is: Mine's by-user index may still miss a room just entered, and
    /// the Chats split view shows only rooms Mine lists.
    func openChat() async {
        await perform("Open chat") { [self] in
            let room = try await groupRepository.group(id: destination.id)
            if room.isMember { myGroups.add(room) }
            navigation.open(chat: room)
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
