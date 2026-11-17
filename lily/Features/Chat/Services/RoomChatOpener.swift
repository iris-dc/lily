import Foundation

/// Opens the chat behind an event or a tournament: the room is a group under the surface's id, fetched for the chat,
/// placed in Mine when the caller is a member (its by-user index may still miss a room just entered, and the Chats
/// tab lists only rooms Mine holds) and handed back for the caller to push in place.
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
        if room.isMember { myGroups.add(room) }
        return room
    }
}
