import Foundation

nonisolated struct ErrorMessage: Equatable, Sendable {
    let title: String
    let body: String
}

/// The one place where typed errors become user-facing copy.
nonisolated enum ErrorMessageMapper {
    static func message(for error: AppError) -> ErrorMessage {
        switch error {
        case .authCancelled, .authFailed, .providerUnavailable, .invalidCredentials, .emailTaken, .emailNotConfirmed,
             .invalidConfirmationCode, .tooManyAttempts, .sessionExpired:
            authMessage(for: error)
        case .network:
            ErrorMessage(title: "You're offline", body: "Check your connection and try again.")
        case .rateLimited:
            ErrorMessage(title: "Slow down a moment", body: "Too many requests. Try again in a few seconds.")
        case .eventsUnavailable, .eventNotFound, .eventFull, .alreadyJoined, .notAParticipant, .hostCannotLeave,
             .tryAgain, .participationFailed, .eventCreationFailed:
            eventMessage(for: error)
        case .groupsUnavailable, .groupNotFound, .groupFull, .notAMember, .bannedFromGroup, .memberBanned,
             .ownerCannotLeave, .insufficientRole, .membershipLimitReached, .groupCreationFailed, .groupActionFailed,
             .contentRejected, .inviteExpired, .inviteUnavailable, .inboxUnavailable, .inviteActionFailed,
             .inviteNotPending, .alreadyMember, .cannotInvite:
            groupMessage(for: error)
        case .chatUnavailable, .messageSendFailed, .messageNotFound:
            chatMessage(for: error)
        case .reportFailed, .blockLimitReached, .userNotFound, .accountSuspended, .termsRequired:
            moderationMessage(for: error)
        case .unknown:
            unknownMessage
        }
    }

    /// The fallback of every domain branch, so a case missing from one reads generic instead of crashing.
    static let unknownMessage = ErrorMessage(title: "Something went wrong",
                                             body: "An unexpected error occurred. Please try again.")

    /// Copy for signing in, signing up and the session; `message(for:)` routes exactly those cases here.
    private static func authMessage(for error: AppError) -> ErrorMessage {
        switch error {
        case .authCancelled:
            ErrorMessage(title: "Sign-in cancelled", body: "No worries. You can try again whenever you like.")
        case .authFailed(let provider):
            ErrorMessage(title: "Couldn't sign in", body: "\(provider.displayName) sign-in didn't go through. Please try again.")
        case .providerUnavailable(let provider):
            ErrorMessage(title: "Coming soon",
                         body: "Sign in with \(provider.displayName) isn't available yet. Use your email for now.")
        case .invalidCredentials:
            ErrorMessage(title: "Check your details", body: "The email or password doesn't look right.")
        case .emailTaken:
            ErrorMessage(title: "Email already in use", body: "There's already an account with this email. Sign in instead.")
        case .emailNotConfirmed:
            ErrorMessage(title: "Confirm your email", body: "Enter the code we sent you to finish setting up your account.")
        case .invalidConfirmationCode:
            ErrorMessage(title: "That code didn't match", body: "Check the code in your email, or ask for a new one.")
        case .tooManyAttempts:
            ErrorMessage(title: "Too many attempts", body: "Please wait a moment before trying again.")
        case .sessionExpired:
            ErrorMessage(title: "Session expired", body: "Please sign in again to continue.")
        default:
            unknownMessage
        }
    }

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
        case .tryAgain:
            ErrorMessage(title: "Please try again", body: "Someone made a change at the same moment. Give it another tap.")
        case .participationFailed:
            ErrorMessage(title: "Couldn't update your spot", body: "Please try again in a moment.")
        case .eventCreationFailed:
            ErrorMessage(title: "Couldn't create your game", body: "Check the details and try again in a moment.")
        default:
            unknownMessage
        }
    }
}
