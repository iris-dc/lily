import Foundation

/// Backend error codes with user-facing copy of their own. Anything else falls back to the caller's generic error.
nonisolated enum BackendErrorCode: String, CaseIterable, Sendable {
    case eventNotFound = "EVENT_NOT_FOUND"
    case eventFull = "EVENT_FULL"
    case alreadyJoined = "ALREADY_JOINED"
    case notAParticipant = "NOT_A_PARTICIPANT"
    case hostCannotLeave = "HOST_CANNOT_LEAVE"
    /// An edit by anyone but the host.
    case notHost = "NOT_HOST"
    /// An edit asking for fewer spots than people already in.
    case capacityTooLow = "CAPACITY_TOO_LOW"
    /// A write lost a race with another player or was throttled; repeating it is safe.
    case tryAgain = "TRY_AGAIN"
    /// The caller sent too many requests; the backend answers 429 with it and a `Retry-After` header.
    case rateLimited = "RATE_LIMITED"
    case contentRejected = "CONTENT_REJECTED"
    case forbidden = "FORBIDDEN"
    case notAMember = "NOT_A_MEMBER"
    case banned = "BANNED"
    case accountSuspended = "ACCOUNT_SUSPENDED"
    case termsRequired = "TERMS_REQUIRED"
    case groupNotFound = "GROUP_NOT_FOUND"
    case messageNotFound = "MESSAGE_NOT_FOUND"
    case userNotFound = "USER_NOT_FOUND"
    /// Another user owns the client id; like `GROUP_ID_REUSED` it becomes the generic creation failure, and the
    /// refetch by client id that follows every unknown create outcome finds the group that did land.
    case groupIdTaken = "GROUP_ID_TAKEN"
    case groupIdReused = "GROUP_ID_REUSED"
    case groupFull = "GROUP_FULL"
    case ownerCannotLeave = "OWNER_CANNOT_LEAVE"
    case memberBanned = "MEMBER_BANNED"
    case membershipLimit = "MEMBERSHIP_LIMIT"
    case inviteExpired = "INVITE_EXPIRED"
    /// Answered already, or the inbox item is unknown or not an invite; either way there is nothing left to answer.
    case inviteNotPending = "INVITE_NOT_PENDING"
    case inboxItemNotFound = "INBOX_ITEM_NOT_FOUND"
    case alreadyMember = "ALREADY_MEMBER"
    case cannotInvite = "CANNOT_INVITE"
    case blockLimit = "BLOCK_LIMIT"
    /// The caller holds the maximum number of direct conversations.
    case conversationLimit = "CONVERSATION_LIMIT"
    /// A reply named a message that is gone, deleted, or below the caller's history floor.
    case replyTargetNotFound = "REPLY_TARGET_NOT_FOUND"
    /// A send named an attachment the bucket does not hold, or another user's upload; also a link to one that is gone.
    case attachmentNotFound = "ATTACHMENT_NOT_FOUND"
    case attachmentTooLarge = "ATTACHMENT_TOO_LARGE"
    case attachmentTypeNotAllowed = "ATTACHMENT_TYPE_NOT_ALLOWED"
    /// The backend has no bucket configured.
    case attachmentsDisabled = "ATTACHMENTS_DISABLED"
    /// A poll sent into a direct conversation.
    case pollsNotAllowed = "POLLS_NOT_ALLOWED"
    case notAPoll = "NOT_A_POLL"
    /// Who voted was asked of an anonymous poll.
    case pollAnonymous = "POLL_ANONYMOUS"
    /// A system row or a deleted message cannot be pinned.
    case notPinnable = "NOT_PINNABLE"
    case tooManyPins = "TOO_MANY_PINS"
    /// Also a private tournament to an outsider.
    case tournamentNotFound = "TOURNAMENT_NOT_FOUND"
    /// Like the group codes: the generic creation failure, and the refetch by client id finds what did land.
    case tournamentIdTaken = "TOURNAMENT_ID_TAKEN"
    case tournamentIdReused = "TOURNAMENT_ID_REUSED"
    case tournamentLimit = "TOURNAMENT_LIMIT"
    case notOrganizer = "NOT_ORGANIZER"
    case tournamentLocked = "TOURNAMENT_LOCKED"
    case registrationClosed = "REGISTRATION_CLOSED"
    case tournamentFull = "TOURNAMENT_FULL"
    case alreadyEntered = "ALREADY_ENTERED"
    case teamFull = "TEAM_FULL"
    /// The entry is gone, or the player named is not in it.
    case entryNotFound = "ENTRY_NOT_FOUND"
    case notEnoughEntries = "NOT_ENOUGH_ENTRIES"
    /// A well-formed match id that names no match of the tournament.
    case matchNotFound = "MATCH_NOT_FOUND"
    case notInMatch = "NOT_IN_MATCH"
    case matchNotReady = "MATCH_NOT_READY"
    case drawNotAllowed = "DRAW_NOT_ALLOWED"

    /// Exhaustive, so a code added above without a mapping fails to compile. One switch is fine here: SwiftLint's
    /// `cyclomatic_complexity` and `function_body_length` judge functions, not accessors.
    var appError: AppError {
        switch self {
        case .eventNotFound: .eventNotFound
        case .eventFull: .eventFull
        case .alreadyJoined: .alreadyJoined
        case .notAParticipant: .notAParticipant
        case .hostCannotLeave: .hostCannotLeave
        case .notHost: .notHost
        case .capacityTooLow: .capacityTooLow
        case .tryAgain: .tryAgain
        case .rateLimited: .rateLimited(retryAfter: nil)
        case .contentRejected: .contentRejected
        case .forbidden: .insufficientRole
        case .notAMember: .notAMember
        case .banned: .bannedFromGroup
        case .accountSuspended: .accountSuspended
        case .termsRequired: .termsRequired
        case .groupNotFound: .groupNotFound
        case .messageNotFound: .messageNotFound
        case .userNotFound: .userNotFound
        case .groupIdTaken, .groupIdReused: .groupCreationFailed
        case .groupFull: .groupFull
        case .ownerCannotLeave: .ownerCannotLeave
        case .memberBanned: .memberBanned
        case .membershipLimit: .membershipLimitReached
        case .inviteExpired: .inviteExpired
        case .inviteNotPending, .inboxItemNotFound: .inviteNotPending
        case .alreadyMember: .alreadyMember
        case .cannotInvite: .cannotInvite
        case .blockLimit: .blockLimitReached
        case .conversationLimit: .conversationLimit
        case .replyTargetNotFound: .replyTargetNotFound
        case .attachmentNotFound: .attachmentNotFound
        // The code does not say which room; the composer restates the error with the room's caps before the popup.
        case .attachmentTooLarge: .attachmentTooLarge(caps: .group)
        case .attachmentTypeNotAllowed: .attachmentTypeNotAllowed
        case .attachmentsDisabled: .attachmentsDisabled
        case .pollsNotAllowed: .pollsNotAllowed
        case .notAPoll: .notAPoll
        case .pollAnonymous: .pollAnonymous
        case .notPinnable: .notPinnable
        case .tooManyPins: .tooManyPins
        case .tournamentNotFound: .tournamentNotFound
        case .tournamentIdTaken, .tournamentIdReused: .tournamentCreationFailed
        case .tournamentLimit: .tournamentLimit
        case .notOrganizer: .notOrganizer
        case .tournamentLocked: .tournamentLocked
        case .registrationClosed: .registrationClosed
        case .tournamentFull: .tournamentFull
        case .alreadyEntered: .alreadyEntered
        case .teamFull: .teamFull
        case .entryNotFound: .entryNotFound
        case .notEnoughEntries: .notEnoughEntries
        case .matchNotFound: .matchNotFound
        case .notInMatch: .notInMatch
        case .matchNotReady: .matchNotReady
        case .drawNotAllowed: .drawNotAllowed
        }
    }
}

extension APIError {
    /// A 401 means the token was rejected and a 429 that the caller was throttled, whatever was asked (both may come
    /// without a body); a known backend code becomes its own case; every other API failure becomes `fallback`.
    func appError(fallback: AppError) -> AppError {
        guard case .http(let status, let body, let retryAfter) = self else { return fallback }
        if status == AppConfig.API.unauthorizedStatus { return .sessionExpired }
        if status == AppConfig.API.rateLimitedStatus { return .rateLimited(retryAfter: retryAfter) }
        guard let body, let code = BackendErrorCode(rawValue: body.code) else { return fallback }
        return code.appError
    }
}

extension APIClient {
    /// `send` for callers that show failures: known backend codes map to their `AppError`, transport failures to
    /// `.network`, everything else to `fallback`. Cancellation passes through unchanged so screens can stay quiet.
    func send<Response: Decodable>(_ request: APIRequest<Response>, failingWith fallback: AppError) async throws -> Response {
        do {
            return try await send(request)
        } catch let error as APIError {
            throw error.appError(fallback: fallback)
        } catch let error as URLError where error.code != .cancelled {
            throw AppError.network
        }
    }
}
