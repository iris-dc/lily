import Foundation

/// What the event detail offers the caller. Decided in one place so the control and its tests agree.
nonisolated enum Participation: Equatable, Sendable {
    /// Guests see no control; joining needs an account.
    case hidden
    case join
    case leave
    /// No spots left and the caller is not in, so there is nothing to do.
    case full
    /// The host is in for good; neither join nor leave applies.
    case hosting

    init(event: SportEvent, userID: String?) {
        guard let userID else {
            self = .hidden
            return
        }
        if event.isHosted(by: userID) {
            self = .hosting
        } else if event.participates {
            self = .leave
        } else if event.isFull {
            self = .full
        } else {
            self = .join
        }
    }
}
