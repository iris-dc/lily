import Foundation

/// What the My Events tab shows for a session state. Joined events belong to a user, so only a signed-in
/// session may ask for them; everyone else is invited to sign in instead.
nonisolated enum MyEventsContent: Equatable, Sendable {
    case signInPrompt
    case joinedEvents

    init(for state: SessionState) {
        self = state.user == nil ? .signInPrompt : .joinedEvents
    }
}
