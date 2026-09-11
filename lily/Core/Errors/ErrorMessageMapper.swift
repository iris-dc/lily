import Foundation

nonisolated struct ErrorMessage: Equatable, Sendable {
    let title: String
    let body: String
}

/// The one place where typed errors become user-facing copy.
nonisolated enum ErrorMessageMapper {
    static func message(for error: AppError) -> ErrorMessage {
        switch error {
        case .authCancelled:
            ErrorMessage(title: "Sign-in cancelled", body: "No worries. You can try again whenever you like.")
        case .authFailed(let provider):
            ErrorMessage(title: "Couldn't sign in", body: "\(provider.displayName) sign-in didn't go through. Please try again.")
        case .invalidCredentials:
            ErrorMessage(title: "Check your details", body: "The email or password doesn't look right.")
        case .sessionExpired:
            ErrorMessage(title: "Session expired", body: "Please sign in again to continue.")
        case .network:
            ErrorMessage(title: "You're offline", body: "Check your connection and try again.")
        case .eventsUnavailable, .eventNotFound, .eventFull, .alreadyJoined, .notAParticipant, .hostCannotLeave:
            eventMessage(for: error)
        case .unknown:
            unknownMessage
        }
    }

    private static let unknownMessage = ErrorMessage(title: "Something went wrong",
                                                     body: "An unexpected error occurred. Please try again.")

    /// Copy for browsing, joining and leaving events; `message(for:)` routes exactly those cases here.
    private static func eventMessage(for error: AppError) -> ErrorMessage {
        switch error {
        case .eventsUnavailable:
            ErrorMessage(title: "Events unavailable", body: "We couldn't load events right now. Pull to refresh in a moment.")
        case .eventNotFound:
            ErrorMessage(title: "Game not found", body: "This game no longer exists. Pull to refresh the list.")
        case .eventFull:
            ErrorMessage(title: "Event is full", body: "Someone took the last spot. Try another game nearby.")
        case .alreadyJoined:
            ErrorMessage(title: "You're already in", body: "You have already joined this game.")
        case .notAParticipant:
            ErrorMessage(title: "Not in this game", body: "You're not on the list for this game, so there is nothing to leave.")
        case .hostCannotLeave:
            ErrorMessage(title: "You're the host", body: "Hosts can't leave their own game.")
        default:
            unknownMessage
        }
    }
}
