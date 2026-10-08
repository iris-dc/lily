import Foundation

/// What a keyboard shortcut asks the shell to create. Explore's screen owns the create sheets, so the intent is
/// parked on `AppNavigation` until Explore is on screen and consumes it (a guest is offered sign-in instead).
nonisolated enum CreateIntent: Hashable, Sendable {
    case game
    case group
    case tournament
}
