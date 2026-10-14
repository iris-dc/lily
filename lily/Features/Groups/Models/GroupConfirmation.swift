import Foundation

/// An action of the group detail waiting for the caller's word, with the words the dialog uses. All four take
/// something away (the caller's membership, the group, another member's place or their right to return), so every
/// button is destructive.
nonisolated enum GroupConfirmation: Hashable, Identifiable, Sendable {
    case leave
    case delete
    case remove(GroupMember)
    case ban(GroupMember)

    var id: Self { self }

    private typealias Copy = AppBranding.Groups

    func title(groupName: String) -> String {
        switch self {
        case .leave: Copy.leaveConfirmation(groupName: groupName)
        case .delete: Copy.deleteConfirmation(groupName: groupName)
        case .remove(let member): Copy.removeConfirmation(memberName: member.displayName)
        case .ban(let member): Copy.banConfirmation(memberName: member.displayName)
        }
    }

    var buttonTitle: String {
        switch self {
        case .leave: Copy.leave
        case .delete: Copy.delete
        case .remove: Copy.removeMember
        case .ban: Copy.banMember
        }
    }
}
