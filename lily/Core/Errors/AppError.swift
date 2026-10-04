import Foundation

/// Every failure the app can surface to the user. Mapped to copy in `ErrorMessageMapper`.
nonisolated enum AppError: Error, Equatable, Sendable {
    /// Reserved for a provider reporting that the user backed out (Cognito / `ASAuthorizationError.canceled`);
    /// task cancellation is handled quietly in `SessionController` and never reaches the popup.
    case authCancelled
    case authFailed(provider: AuthProvider.Kind)
    /// Apple and Google stay on the sheet but have no identity provider in the pool yet.
    case providerUnavailable(provider: AuthProvider.Kind)
    case invalidCredentials
    case emailTaken
    /// The account exists but the emailed code was never entered; the form offers the code step, no popup.
    case emailNotConfirmed
    case invalidConfirmationCode
    case tooManyAttempts
    /// The backend rejected the token (401), or Amplify could not refresh it.
    case sessionExpired
    /// The backend throttled the caller (429 `RATE_LIMITED`); the request is fine to repeat after `retryAfter`
    /// seconds, when the `Retry-After` header named them.
    case rateLimited(retryAfter: TimeInterval?)
    case network
    case eventsUnavailable
    case eventNotFound
    case eventFull
    case alreadyJoined
    case notAParticipant
    case hostCannotLeave
    case tryAgain
    /// A join or leave failed for a reason without copy of its own (a 500, an unreadable body).
    case participationFailed
    /// Creating an event failed for a reason without copy of its own (a 500, a validation the form did not catch).
    case eventCreationFailed
    /// The backend refused an edit by someone other than the host (`NOT_HOST`).
    case notHost
    /// An edit asked for fewer spots than people already in the game (`CAPACITY_TOO_LOW`).
    case capacityTooLow
    /// Editing an event failed for a reason without copy of its own (a 500, a validation the form did not catch).
    case eventUpdateFailed
    case groupsUnavailable
    /// Also what a private group answers to anyone who is not a member, on reads and writes alike.
    case groupNotFound
    case groupFull
    case notAMember
    /// The caller was banned from the group; disclosed only by a join attempt.
    case bannedFromGroup
    /// The target of a removal is a banned marker; the bans route is the way to unban.
    case memberBanned
    case ownerCannotLeave
    /// The backend refused an action the caller's role does not allow (`FORBIDDEN`).
    case insufficientRole
    case membershipLimitReached
    /// Creating a group failed for a reason without copy of its own, including an id another user owns.
    case groupCreationFailed
    /// A group write (join, leave, update, role change, invite) failed for a reason without copy of its own.
    case groupActionFailed
    /// A name, description or message tripped the word filter or the link policy.
    case contentRejected
    /// The invite's seven days are over (`INVITE_EXPIRED`); a verdict on the invite, never retried.
    case inviteExpired
    /// Sending an invite failed for a reason without a code of its own (a 500, an unreadable body).
    case inviteUnavailable
    /// The inbox page or the read marker failed for a reason without a code of its own.
    case inboxUnavailable
    /// Accepting or declining failed for a reason without a code of its own; repeating the tap is safe.
    case inviteActionFailed
    /// The invite was answered already, or the item is gone (`INVITE_NOT_PENDING`, `INBOX_ITEM_NOT_FOUND`).
    case inviteNotPending
    /// The person invited is in the group already (`ALREADY_MEMBER`).
    case alreadyMember
    /// The person invited is banned from the group (`CANNOT_INVITE`).
    case cannotInvite
    case chatUnavailable
    case messageSendFailed
    case messageNotFound
    /// The message a reply answers is gone (deleted, or below the caller's history floor; `REPLY_TARGET_NOT_FOUND`).
    case replyTargetNotFound
    /// A send named an attachment the bucket does not hold, or one another user uploaded (`ATTACHMENT_NOT_FOUND`).
    case attachmentNotFound
    /// The picture is over its cap after the device re-encoded it, or the backend measured it so (`ATTACHMENT_TOO_LARGE`).
    case attachmentTooLarge
    /// Not a picture the app can send, or a type the backend refuses (`ATTACHMENT_TYPE_NOT_ALLOWED`).
    case attachmentTypeNotAllowed
    /// The backend runs without a bucket (`ATTACHMENTS_DISABLED`); `GET /api/me` says so too and the button hides.
    case attachmentsDisabled
    /// The upload ticket or the PUT itself failed for a reason without a code of its own; Retry asks for a new ticket.
    case attachmentUploadFailed
    /// A link refresh or a download failed for a reason without a code of its own.
    case attachmentUnavailable
    case reportFailed
    case blockLimitReached
    case userNotFound
    /// The caller's account was suspended by an operator.
    case accountSuspended
    /// A write needs the current terms of use accepted first.
    case termsRequired
    /// Loading a person's profile failed for a reason without a code of its own.
    case profileUnavailable
    /// Starting a direct conversation failed for a reason without a code of its own; repeating is safe (one id per pair).
    case conversationFailed
    /// The caller holds `AppConfig.People.maxConversations` conversations already (`CONVERSATION_LIMIT`).
    case conversationLimit
    case tournamentsUnavailable
    /// Also what a private tournament answers to an outsider, and what a deleted one answers.
    case tournamentNotFound
    /// Creating a tournament failed for a reason without copy of its own, including an id another organiser owns.
    case tournamentCreationFailed
    case tournamentUpdateFailed
    /// A tournament write (an entry, a result, a cancel) failed for a reason without copy of its own.
    case tournamentActionFailed
    /// Entries are over: the tournament started, was cancelled or passed its deadline (`REGISTRATION_CLOSED`).
    case registrationClosed
    case tournamentFull
    /// The caller holds an entry already, alone or in a team (`ALREADY_ENTERED`).
    case alreadyEntered
    case teamFull
    /// The entry is gone, or the player is not in it (`ENTRY_NOT_FOUND`).
    case entryNotFound
    /// The backend refused what only the organiser may do (`NOT_ORGANIZER`).
    case notOrganizer
    /// After the start only the name, description and place may change; completed and cancelled lock everything.
    case tournamentLocked
    case notEnoughEntries
    /// A result from someone who is on neither side of the match (`NOT_IN_MATCH`).
    case notInMatch
    /// The match misses a side, is decided already, or the tournament is not in progress (`MATCH_NOT_READY`).
    case matchNotReady
    /// A well-formed match id that names no match of the tournament (`MATCH_NOT_FOUND`).
    case matchNotFound
    case drawNotAllowed
    /// The organiser runs `AppConfig.Tournaments.maxOrganizedOpen` open tournaments already (`TOURNAMENT_LIMIT`).
    case tournamentLimit
    /// The person invited into a tournament is in it already (`ALREADY_ENTERED` on an invite).
    case inviteeAlreadyEntered
    /// Only entrants and the organiser invite into a tournament (`FORBIDDEN` on an invite).
    case cannotInviteToTournament
    case unknown

    /// Normalises any thrown error into an `AppError`.
    static func wrapping(_ error: any Error) -> AppError {
        if let appError = error as? AppError { return appError }
        if error is CancellationError { return .authCancelled }
        if (error as? URLError) != nil { return .network }
        return .unknown
    }

    /// The caller left mid-request (screen dismissed, task cancelled): not a failure, never shown.
    static func isCancellation(_ error: any Error) -> Bool {
        Task.isCancelled || error is CancellationError || (error as? URLError)?.code == .cancelled
    }
}
