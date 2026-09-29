import Foundation

/// What the Home tab shows for a session state. The caller's groups and games belong to a user, so only a signed-in
/// session may ask for them; everyone else is invited to sign in instead.
nonisolated enum HomeContent: Equatable, Sendable {
    case signInPrompt
    case overview

    init(for state: SessionState) {
        self = state.user == nil ? .signInPrompt : .overview
    }
}
