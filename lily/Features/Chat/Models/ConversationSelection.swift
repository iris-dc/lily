import Foundation

/// What the Chats split view shows in its detail column on a regular width: the inbox or one room, by id. The room
/// is looked up in `MyGroupsStore` when drawn, so a room the caller lost falls back to the empty state by itself.
nonisolated enum ConversationSelection: Hashable, Sendable {
    case inbox
    case room(id: String)

    /// Whether the detail column can still show this: the inbox always, a room while Mine lists it.
    func isAvailable(in groups: [SportGroup]) -> Bool {
        switch self {
        case .inbox: true
        case .room(let id): groups.contains { $0.id == id }
        }
    }
}
