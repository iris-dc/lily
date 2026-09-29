import Foundation

/// Backend error codes with user-facing copy of their own. Anything else falls back to the caller's generic error.
nonisolated enum BackendErrorCode: String, CaseIterable, Sendable {
    case eventNotFound = "EVENT_NOT_FOUND"
    case eventFull = "EVENT_FULL"
    case alreadyJoined = "ALREADY_JOINED"
    case notAParticipant = "NOT_A_PARTICIPANT"
    case hostCannotLeave = "HOST_CANNOT_LEAVE"
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
    case reportNotFound = "REPORT_NOT_FOUND"
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

    /// Every code maps to a case with copy; the domains are split so no switch grows past the complexity limit.
    var appError: AppError {
        eventError ?? groupError ?? inviteError ?? moderationError ?? .unknown
    }

    private var eventError: AppError? {
        switch self {
        case .eventNotFound: .eventNotFound
        case .eventFull: .eventFull
        case .alreadyJoined: .alreadyJoined
        case .notAParticipant: .notAParticipant
        case .hostCannotLeave: .hostCannotLeave
        case .tryAgain: .tryAgain
        case .rateLimited: .rateLimited(retryAfter: nil)
        default: nil
        }
    }

    private var groupError: AppError? {
        switch self {
        case .groupNotFound: .groupNotFound
        case .groupFull: .groupFull
        case .notAMember: .notAMember
        case .banned: .bannedFromGroup
        case .memberBanned: .memberBanned
        case .ownerCannotLeave: .ownerCannotLeave
        case .forbidden: .insufficientRole
        case .membershipLimit: .membershipLimitReached
        case .groupIdTaken, .groupIdReused: .groupCreationFailed
        default: nil
        }
    }

    private var inviteError: AppError? {
        switch self {
        case .inviteExpired: .inviteExpired
        case .inviteNotPending, .inboxItemNotFound: .inviteNotPending
        case .alreadyMember: .alreadyMember
        case .cannotInvite: .cannotInvite
        default: nil
        }
    }

    private var moderationError: AppError? {
        switch self {
        case .contentRejected: .contentRejected
        case .messageNotFound: .messageNotFound
        case .reportNotFound: .reportFailed
        case .userNotFound: .userNotFound
        case .blockLimit: .blockLimitReached
        case .accountSuspended: .accountSuspended
        case .termsRequired: .termsRequired
        default: nil
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
