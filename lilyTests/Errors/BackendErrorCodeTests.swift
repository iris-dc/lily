import Foundation
import Testing
@testable import lily

/// Every case of `BackendErrorCode` has an `AppError` and copy of its own, never the generic one; the fallback is the
/// caller's, never `.unknown`. The enum is exhaustive as a switch, not as a copy of Laurel's list: the codes Laurel
/// answers only to its framework (`VALIDATION_FAILED`, `NOT_FOUND`) or to operators have no case on purpose.
struct BackendErrorCodeTests {
    /// Laurel's `ErrorCodes` minus `BackendErrorCode`: the framework and status codes a conforming app never earns, and
    /// the two codes of the operator routes the app does not call.
    private static let codesWithoutACase = [
        "VALIDATION_FAILED", "UNAUTHENTICATED", "INTERNAL_ERROR", "NOT_FOUND", "METHOD_NOT_ALLOWED",
        "UNSUPPORTED_MEDIA_TYPE", "REPORT_NOT_FOUND", "FEEDBACK_NOT_FOUND",
    ]

    @Test(arguments: BackendErrorCode.allCases)
    func everyCodeHasItsOwnCopy(code: BackendErrorCode) {
        #expect(code.appError != .unknown, "\(code.rawValue) fell through")
        #expect(ErrorMessageMapper.message(for: code.appError) != ErrorMessageMapper.unknownMessage,
                "\(code.rawValue) reads the generic copy")
    }

    @Test func everyCodeMapsToItsCase() {
        let expected: [String: AppError] = [
            "EVENT_NOT_FOUND": .eventNotFound, "EVENT_FULL": .eventFull, "ALREADY_JOINED": .alreadyJoined,
            "NOT_A_PARTICIPANT": .notAParticipant, "HOST_CANNOT_LEAVE": .hostCannotLeave, "NOT_HOST": .notHost,
            "CAPACITY_TOO_LOW": .capacityTooLow, "TRY_AGAIN": .tryAgain, "RATE_LIMITED": .rateLimited(retryAfter: nil),
            "CONTENT_REJECTED": .contentRejected, "FORBIDDEN": .insufficientRole, "NOT_A_MEMBER": .notAMember,
            "BANNED": .bannedFromGroup, "ACCOUNT_SUSPENDED": .accountSuspended, "TERMS_REQUIRED": .termsRequired,
            "GROUP_NOT_FOUND": .groupNotFound, "MESSAGE_NOT_FOUND": .messageNotFound,
            "USER_NOT_FOUND": .userNotFound, "EVENT_ID_TAKEN": .eventCreationFailed, "EVENT_ID_REUSED": .createIdReused,
            "GROUP_ID_TAKEN": .groupCreationFailed, "REQUEST_TOO_LARGE": .requestTooLarge, "INVITE_LIMIT": .tournamentInviteLimit,
            "GROUP_ID_REUSED": .createIdReused, "GROUP_FULL": .groupFull, "OWNER_CANNOT_LEAVE": .ownerCannotLeave,
            "MEMBER_BANNED": .memberBanned, "MEMBERSHIP_LIMIT": .membershipLimitReached,
            "INVITE_EXPIRED": .inviteExpired, "INVITE_NOT_PENDING": .inviteNotPending,
            "INBOX_ITEM_NOT_FOUND": .inviteNotPending, "ALREADY_MEMBER": .alreadyMember, "CANNOT_INVITE": .cannotInvite,
            "BLOCK_LIMIT": .blockLimitReached, "CONVERSATION_LIMIT": .conversationLimit,
            "REPLY_TARGET_NOT_FOUND": .replyTargetNotFound, "ATTACHMENT_NOT_FOUND": .attachmentNotFound,
            "ATTACHMENT_TOO_LARGE": .attachmentTooLarge(caps: .group), "ATTACHMENT_TYPE_NOT_ALLOWED": .attachmentTypeNotAllowed,
            "ATTACHMENTS_DISABLED": .attachmentsDisabled, "TOURNAMENT_NOT_FOUND": .tournamentNotFound,
            "POLLS_NOT_ALLOWED": .pollsNotAllowed, "NOT_A_POLL": .notAPoll, "POLL_ANONYMOUS": .pollAnonymous,
            "NOT_PINNABLE": .notPinnable, "TOO_MANY_PINS": .tooManyPins,
            "TOURNAMENT_ID_TAKEN": .tournamentCreationFailed, "TOURNAMENT_ID_REUSED": .createIdReused,
            "TOURNAMENT_LIMIT": .tournamentLimit, "NOT_ORGANIZER": .notOrganizer, "TOURNAMENT_LOCKED": .tournamentLocked,
            "REGISTRATION_CLOSED": .registrationClosed, "TOURNAMENT_FULL": .tournamentFull, "ALREADY_ENTERED": .alreadyEntered,
            "TEAM_FULL": .teamFull, "ENTRY_NOT_FOUND": .entryNotFound, "NOT_ENOUGH_ENTRIES": .notEnoughEntries,
            "NOT_IN_MATCH": .notInMatch, "MATCH_NOT_READY": .matchNotReady, "MATCH_NOT_FOUND": .matchNotFound,
            "DRAW_NOT_ALLOWED": .drawNotAllowed,
        ]
        for (raw, error) in expected {
            #expect(BackendErrorCode(rawValue: raw)?.appError == error, "\(raw)")
        }
        #expect(Set(expected.keys) == Set(BackendErrorCode.allCases.map(\.rawValue)), "every case of the enum is in this table")
        #expect(APIError.http(status: 403, body: APIErrorBody(code: "TERMS_REQUIRED", message: "m")).appError(fallback: .unknown)
                == .termsRequired)
    }

    /// Laurel's 69 codes are the enum's 61 plus these eight; each falls to the fallback of the route it arrived on, as
    /// `REPORT_NOT_FOUND` (the operator's per-report routes, which the app never calls) always has.
    @Test(arguments: codesWithoutACase)
    func laurelsFrameworkAndOperatorCodesHaveNoCaseOnPurpose(code: String) {
        #expect(BackendErrorCode(rawValue: code) == nil)
        let failure = APIError.http(status: 404, body: APIErrorBody(code: code, message: "m"))
        #expect(failure.appError(fallback: .reportFailed) == .reportFailed)
        #expect(failure.appError(fallback: .groupNotFound) == .groupNotFound)
    }

    @Test func theEnumAndTheCodesWithoutACaseAreLaurelsList() {
        #expect(BackendErrorCode.allCases.count == 61)
        #expect(Set(Self.codesWithoutACase).isDisjoint(with: BackendErrorCode.allCases.map(\.rawValue)))
    }
}
