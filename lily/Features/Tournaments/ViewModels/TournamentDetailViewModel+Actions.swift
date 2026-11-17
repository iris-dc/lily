import Foundation

/// The actions that write no entry and no match, shared by the menu and the in-body action row: opening the room's
/// chat and the organiser's cancel. Out of the main file, which is at the type-body limit.
extension TournamentDetailViewModel {
    /// The room is a group under the tournament's id: `RoomChatOpener` fetches it (the chat needs the group as the
    /// backend holds it) and places a member room into Mine, as an accepted invite's is. The chat is pushed on the
    /// detail's own stack (`openedRoom`), so Back returns to the tournament rather than landing on the Chats list,
    /// like a profile's "Message". A room the fetch cannot answer — gone, or private and the caller not in it — is
    /// reported as the tournament's chat, never as a missing group.
    func openChat() async {
        guard permissions.canOpenChat else { return }
        await perform("Open chat") { [self] in
            openedRoom = try await roomOpener.room(id: destination.id, whenUnavailable: .tournamentChatUnavailable)
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

    /// The chat opener shared with the event detail: fetch, remap a missing room, place a member room in Mine.
    private var roomOpener: RoomChatOpener {
        RoomChatOpener(groupRepository: groupRepository, myGroups: myGroups)
    }
}
