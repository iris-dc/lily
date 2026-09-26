import Foundation

/// What Mine shows on the Groups tab for a session state. Discover works for everyone; a caller's groups need an
/// account, so guests are asked to sign in there instead of a `scope=mine` request nothing could answer.
nonisolated enum GroupsContent: Equatable, Sendable {
    case signInPrompt
    case myGroups

    init(for state: SessionState) {
        self = state.user == nil ? .signInPrompt : .myGroups
    }

    /// Where the tab opens: a guest has nothing under Mine, so Discover comes first for them.
    var initialScope: GroupListScope {
        self == .signInPrompt ? .discover : .mine
    }
}
