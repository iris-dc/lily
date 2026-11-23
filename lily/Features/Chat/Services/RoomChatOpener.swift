import Foundation

/// Opens the chat behind an event or a tournament: the room is a group under the surface's id, fetched for the chat,
/// placed in Mine when the caller is a member and Mine lacks it (the by-user index may still miss a room just
/// entered, and the Chats tab lists only rooms Mine holds; a held copy is never replaced and no change is recorded —
/// opening a chat is a read) and handed back for the caller to push in place.
struct RoomChatOpener {
    let groupRepository: any GroupRepository
    let myGroups: MyGroupsStore

    /// `group(id:)` answers `.groupNotFound` both for a room the backend does not hold and for a private room the
    /// caller is not in; either way the popup must name the surface's chat, never a missing group, so the caller's
    /// error replaces it. Every other failure keeps its own copy.
    func room(id: String, whenUnavailable unavailable: AppError) async throws -> SportGroup {
        let room: SportGroup
        do {
            room = try await groupRepository.group(id: id)
        } catch AppError.groupNotFound {
            throw unavailable
        }
        if room.isMember && !myGroups.groups.contains(where: { $0.id == room.id }) {
            myGroups.add(room)
        }
        return room
    }
}
