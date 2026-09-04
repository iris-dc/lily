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
        case .eventsUnavailable:
            ErrorMessage(title: "Events unavailable", body: "We couldn't load events right now. Pull to refresh in a moment.")
        case .unknown:
            ErrorMessage(title: "Something went wrong", body: "An unexpected error occurred. Please try again.")
        }
    }
}
