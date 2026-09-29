import Foundation

/// What the Home and Chats tabs show for a session state. The caller's groups, games and conversations belong to a
/// user, so only a signed-in session may ask for them; everyone else is invited to sign in instead.
nonisolated enum HomeContent: Equatable, Sendable {
    case signInPrompt
    case overview

    init(for state: SessionState) {
        self = state.user == nil ? .signInPrompt : .overview
    }
}
