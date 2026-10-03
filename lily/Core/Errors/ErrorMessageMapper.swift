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
            ErrorMessage(title: localized("You're offline"), body: localized("Check your connection and try again."))
        case .rateLimited:
            ErrorMessage(title: localized("Slow down a moment"),
                         body: localized("Too many requests. Try again in a few seconds."))
        case .eventsUnavailable, .eventNotFound, .eventFull, .alreadyJoined, .notAParticipant, .hostCannotLeave,
             .tryAgain, .participationFailed, .eventCreationFailed, .notHost, .capacityTooLow, .eventUpdateFailed:
            eventMessage(for: error)
        case .groupsUnavailable, .groupNotFound, .groupFull, .notAMember, .bannedFromGroup, .memberBanned,
             .ownerCannotLeave, .insufficientRole, .membershipLimitReached, .groupCreationFailed, .groupActionFailed,
             .contentRejected, .inviteExpired, .inviteUnavailable, .inboxUnavailable, .inviteActionFailed,
             .inviteNotPending, .alreadyMember, .cannotInvite:
            groupMessage(for: error)
        case .chatUnavailable, .messageSendFailed, .messageNotFound, .replyTargetNotFound:
            chatMessage(for: error)
        case .attachmentNotFound, .attachmentTooLarge, .attachmentTypeNotAllowed, .attachmentsDisabled,
             .attachmentUploadFailed, .attachmentUnavailable:
            attachmentMessage(for: error)
        case .reportFailed, .blockLimitReached, .userNotFound, .accountSuspended, .termsRequired:
            moderationMessage(for: error)
        case .profileUnavailable, .conversationFailed, .conversationLimit:
            peopleMessage(for: error)
        case .unknown:
            unknownMessage
        }
    }

    /// The fallback of every domain branch, so a case missing from one reads generic instead of crashing.
    static var unknownMessage: ErrorMessage {
        ErrorMessage(title: localized("Something went wrong"), body: localized("An unexpected error occurred. Please try again."))
    }

    /// Copy for signing in, signing up and the session; `message(for:)` routes exactly those cases here.
    private static func authMessage(for error: AppError) -> ErrorMessage {
        switch error {
        case .authCancelled:
            ErrorMessage(title: localized("Sign-in cancelled"),
                         body: localized("No worries. You can try again whenever you like."))
        case .authFailed(let provider):
            ErrorMessage(title: localized("Couldn't sign in"),
                         body: localized("\(provider.displayName) sign-in didn't go through. Please try again."))
        case .providerUnavailable(let provider):
            ErrorMessage(title: localized("Coming soon"),
                         body: localized("Sign in with \(provider.displayName) isn't available yet. Use your email for now."))
        case .invalidCredentials:
            ErrorMessage(title: localized("Check your details"), body: localized("The email or password doesn't look right."))
        case .emailTaken:
            ErrorMessage(title: localized("Email already in use"),
                         body: localized("There's already an account with this email. Sign in instead."))
        case .emailNotConfirmed:
            ErrorMessage(title: localized("Confirm your email"),
                         body: localized("Enter the code we sent you to finish setting up your account."))
        case .invalidConfirmationCode:
            ErrorMessage(title: localized("That code didn't match"),
                         body: localized("Check the code in your email, or ask for a new one."))
        case .tooManyAttempts:
            ErrorMessage(title: localized("Too many attempts"), body: localized("Please wait a moment before trying again."))
        case .sessionExpired:
            ErrorMessage(title: localized("Session expired"), body: localized("Please sign in again to continue."))
        default:
            unknownMessage
        }
    }

    /// Copy for browsing, joining and leaving events; `message(for:)` routes exactly those cases here, and what a host
    /// does to their own game falls through to `hostMessage(for:)`.
    private static func eventMessage(for error: AppError) -> ErrorMessage {
        switch error {
        case .eventsUnavailable:
            ErrorMessage(title: localized("Events unavailable"),
                         body: localized("We couldn't load events right now. Pull to refresh in a moment."))
        case .eventNotFound:
            ErrorMessage(title: localized("Game not found"),
                         body: localized("This game no longer exists. Pull to refresh the list."))
        case .eventFull:
            ErrorMessage(title: localized("Event is full"),
                         body: localized("Someone took the last spot. Try another game nearby."))
        case .alreadyJoined:
            ErrorMessage(title: localized("You're already in"), body: localized("You have already joined this game."))
        case .notAParticipant:
            ErrorMessage(title: localized("Not in this game"),
                         body: localized("You're not on the list for this game, so there is nothing to leave."))
        case .hostCannotLeave:
            ErrorMessage(title: localized("You're the host"), body: localized("Hosts can't leave their own game."))
        case .tryAgain:
            ErrorMessage(title: localized("Please try again"),
                         body: localized("Someone made a change at the same moment. Give it another tap."))
        case .participationFailed:
            ErrorMessage(title: localized("Couldn't update your spot"), body: localized("Please try again in a moment."))
        default:
            hostMessage(for: error)
        }
    }
}
