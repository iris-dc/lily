import Foundation
import Testing
@testable import lily

struct ErrorMessageMapperTests {
    private static let allErrors: [AppError] = [
        .authCancelled, .authFailed(provider: .apple), .providerUnavailable(provider: .apple), .invalidCredentials,
        .emailTaken, .emailNotConfirmed, .invalidConfirmationCode, .tooManyAttempts,
        .sessionExpired, .rateLimited(retryAfter: nil), .network, .eventsUnavailable, .eventNotFound, .eventFull,
        .alreadyJoined, .notAParticipant, .hostCannotLeave, .tryAgain, .participationFailed, .eventCreationFailed,
        .notHost, .capacityTooLow, .eventUpdateFailed,
        .groupsUnavailable, .groupNotFound, .groupFull, .notAMember, .bannedFromGroup, .memberBanned, .ownerCannotLeave,
        .insufficientRole, .membershipLimitReached, .groupCreationFailed, .groupActionFailed, .contentRejected,
        .inviteExpired, .inviteUnavailable, .inboxUnavailable, .inviteActionFailed, .inviteNotPending, .alreadyMember,
        .cannotInvite, .chatUnavailable, .messageSendFailed, .messageNotFound, .replyTargetNotFound,
        .attachmentNotFound, .attachmentTooLarge, .attachmentTypeNotAllowed, .attachmentsDisabled, .attachmentUploadFailed,
        .attachmentUnavailable,
        .reportFailed, .blockLimitReached, .userNotFound, .accountSuspended, .termsRequired,
        .profileUnavailable, .conversationFailed, .conversationLimit,
        .unknown,
    ]

    /// The event branch of the mapper ends in a generic default, so a case missing from it would read
    /// "Something went wrong" and still pass a non-empty check; only `.unknown` may carry that copy.
    @Test(arguments: allErrors)
    func everyErrorHasCopy(error: AppError) {
        let message = ErrorMessageMapper.message(for: error)
        #expect(!message.title.isEmpty)
        #expect(!message.body.isEmpty)
        #expect(error == .unknown || message != ErrorMessageMapper.message(for: .unknown),
                "\(error) fell through to the generic copy")
    }

    /// Pinned so a change to the refusal copy is a deliberate diff, not a side effect of editing the mapper.
    @Test func participationRefusalsHaveTheirOwnTitles() {
        #expect(ErrorMessageMapper.message(for: .tryAgain).title == "Please try again")
        #expect(ErrorMessageMapper.message(for: .participationFailed).title == "Couldn't update your spot")
    }

    /// `TRY_AGAIN` answers group writes, invites and chat sends as well as joins, so the copy names no game.
    @Test func tryAgainNamesNoDomain() {
        let body = ErrorMessageMapper.message(for: .tryAgain).body
        #expect(body == "Someone made a change at the same moment. Give it another tap.")
    }

    /// Pinned: an invite that could not be sent, an inbox that could not load and an answer that failed each say so,
    /// and a verdict on the invite reads as one, not as a failure to retry.
    @Test func inviteAndInboxFailuresHaveTheirOwnTitles() {
        #expect(ErrorMessageMapper.message(for: .inviteUnavailable).title == "Couldn't send the invite")
        #expect(ErrorMessageMapper.message(for: .inboxUnavailable).title == "Couldn't load your notifications")
        #expect(ErrorMessageMapper.message(for: .inviteActionFailed).title == "Couldn't answer the invite")
        #expect(ErrorMessageMapper.message(for: .inviteNotPending).title == "This invite was already answered")
        #expect(ErrorMessageMapper.message(for: .alreadyMember).title == "They're already in this group")
        #expect(ErrorMessageMapper.message(for: .cannotInvite).title == "This person can't be invited")
    }

    /// An edit's refusals and failures read as the host's, not like a join that failed.
    @Test func hostFailuresHaveTheirOwnTitles() {
        #expect(ErrorMessageMapper.message(for: .eventUpdateFailed).title == "Couldn't save your changes")
        #expect(ErrorMessageMapper.message(for: .notHost).title == "Not your game")
        #expect(ErrorMessageMapper.message(for: .capacityTooLow).title == "Too few spots")
    }

    /// A create that fails for no named reason must not read like a join that failed.
    @Test func creationFailureHasItsOwnTitle() {
        #expect(ErrorMessageMapper.message(for: .eventCreationFailed).title == "Couldn't create your game")
    }

    /// Being throttled is not being offline; the copy asks for a pause, not for a connection check, whatever the wait.
    @Test func rateLimitedHasItsOwnTitle() {
        #expect(ErrorMessageMapper.message(for: .rateLimited(retryAfter: 3)).title == "Slow down a moment")
        let timed = ErrorMessageMapper.message(for: .rateLimited(retryAfter: 3))
        #expect(timed == ErrorMessageMapper.message(for: .rateLimited(retryAfter: nil)))
    }

    /// The `Retry-After` seconds ride along from the API error; a 429 without them still maps.
    @Test func rateLimitedCarriesRetryAfterThroughTheMapping() {
        let throttled = APIErrorBody(code: "RATE_LIMITED", message: "m")
        let timed = APIError.http(status: 429, body: throttled, retryAfter: 3)
        #expect(timed.appError(fallback: .unknown) == .rateLimited(retryAfter: 3))
        #expect(APIError.http(status: 429, body: nil).appError(fallback: .unknown) == .rateLimited(retryAfter: nil))
        #expect(BackendErrorCode.rateLimited.appError == .rateLimited(retryAfter: nil))
    }

    /// Pinned like the event copy: a group refusal must not read like an event one, and the limits come from config.
    @Test func groupChatAndModerationErrorsHaveTheirOwnTitles() {
        #expect(ErrorMessageMapper.message(for: .groupsUnavailable).title == "Groups unavailable")
        #expect(ErrorMessageMapper.message(for: .groupFull).title == "Group is full")
        #expect(ErrorMessageMapper.message(for: .ownerCannotLeave).title == "You own this group")
        #expect(ErrorMessageMapper.message(for: .groupCreationFailed).title == "Couldn't create your group")
        #expect(ErrorMessageMapper.message(for: .inviteExpired).title == "Invite expired")
        #expect(ErrorMessageMapper.message(for: .messageSendFailed).title == "Not sent")
        #expect(ErrorMessageMapper.message(for: .termsRequired).title == "Please accept the updated terms")
        #expect(ErrorMessageMapper.message(for: .replyTargetNotFound)
                == ErrorMessage(title: "That message is gone", body: "It was deleted before your reply was sent."))
        #expect(ErrorMessageMapper.message(for: .membershipLimitReached).body.contains("\(AppConfig.Groups.maxMemberships)"))
        #expect(ErrorMessageMapper.message(for: .accountSuspended).body.contains(AppConfig.Moderation.supportEmail))
    }

    /// Pinned: an attachment refused, missing or failed each say so, and the size caps name the numbers from config
    /// for all three kinds.
    @Test func attachmentErrorsHaveTheirOwnTitles() {
        #expect(ErrorMessageMapper.message(for: .attachmentNotFound).title == "Attachment missing")
        #expect(ErrorMessageMapper.message(for: .attachmentTooLarge).title == "That's too big")
        let caps = ErrorMessageMapper.message(for: .attachmentTooLarge).body
        #expect(caps.contains("10 MB") && caps.contains("50 MB") && caps.contains("3 minutes") && caps.contains("25 MB"))
        #expect(ErrorMessageMapper.message(for: .attachmentTypeNotAllowed).title == "That can't be sent")
        #expect(ErrorMessageMapper.message(for: .attachmentsDisabled).title == "Attachments are off")
        #expect(ErrorMessageMapper.message(for: .attachmentUploadFailed).title == "Couldn't upload the attachment")
        #expect(ErrorMessageMapper.message(for: .attachmentUnavailable).title == "Couldn't load the attachment")
    }

    /// Pinned like the rest: a profile that would not load and a conversation that would not start each say so, and the
    /// conversation cap names the number from config.
    @Test func peopleErrorsHaveTheirOwnTitles() {
        #expect(ErrorMessageMapper.message(for: .profileUnavailable).title == "Couldn't load this profile")
        #expect(ErrorMessageMapper.message(for: .conversationFailed).title == "Couldn't start the conversation")
        #expect(ErrorMessageMapper.message(for: .conversationLimit).title == "You have too many conversations")
        #expect(ErrorMessageMapper.message(for: .conversationLimit).body.contains("\(AppConfig.People.maxConversations)"))
    }

    @Test func providerFailureNamesProvider() {
        #expect(ErrorMessageMapper.message(for: .authFailed(provider: .google)).body.contains("Google"))
    }

    /// Pinned: the sheet keeps Apple and Google visible, so the copy must promise rather than apologise.
    @Test func unavailableProviderIsComingSoonAndPointsToEmail() {
        let message = ErrorMessageMapper.message(for: .providerUnavailable(provider: .google))
        #expect(message.title == "Coming soon")
        #expect(message.body == "Sign in with Google isn't available yet. Use your email for now.")
    }

    @Test func confirmationErrorsHaveTheirOwnTitles() {
        #expect(ErrorMessageMapper.message(for: .emailTaken).title == "Email already in use")
        #expect(ErrorMessageMapper.message(for: .emailNotConfirmed).title == "Confirm your email")
        #expect(ErrorMessageMapper.message(for: .invalidConfirmationCode).title == "That code didn't match")
        #expect(ErrorMessageMapper.message(for: .tooManyAttempts).title == "Too many attempts")
        #expect(ErrorMessageMapper.message(for: .sessionExpired).title == "Session expired")
    }

    @Test func wrappingNormalisesForeignErrors() {
        #expect(AppError.wrapping(AppError.network) == .network)
        #expect(AppError.wrapping(CancellationError()) == .authCancelled)
        #expect(AppError.wrapping(URLError(.notConnectedToInternet)) == .network)
        #expect(AppError.wrapping(NSError(domain: "x", code: 1)) == .unknown)
    }
}

@MainActor
struct ErrorCenterTests {
    @Test func reportPresentsMappedMessageAndLogs() {
        let logger = SpyLogger()
        let center = ErrorCenter(logger: logger)

        center.report(AppError.network)

        #expect(center.current?.error == .network)
        #expect(center.current?.message == ErrorMessageMapper.message(for: .network))
        #expect(logger.messages(in: .ui).count == 1)
    }

    @Test func repeatedReportsGetFreshIdentity() {
        let center = ErrorCenter(logger: SpyLogger())
        center.report(AppError.network)
        let first = center.current?.id
        center.report(AppError.network)
        #expect(center.current?.id != first)
    }

    @Test func dismissWithStaleIdIsIgnored() {
        let center = ErrorCenter(logger: SpyLogger())
        center.report(AppError.network)
        let stale = center.current!.id
        center.report(AppError.unknown)

        center.dismiss(stale)
        #expect(center.current?.error == .unknown)

        center.dismiss()
        #expect(center.current == nil)
    }

    @Test func onlyTheLatestPresenterDraws() {
        let center = ErrorCenter(logger: SpyLogger())
        let root = UUID()
        let sheet = UUID()

        center.beginPresenting(root)
        #expect(center.isTopPresenter(root))

        center.beginPresenting(sheet)
        #expect(center.isTopPresenter(sheet))
        #expect(!center.isTopPresenter(root))

        center.endPresenting(sheet)
        #expect(center.isTopPresenter(root))
    }
}

/// Every code the backend can answer with has a case with copy of its own; the fallback is the caller's, never `.unknown`.
struct BackendErrorCodeTests {
    @Test(arguments: BackendErrorCode.allCases)
    func everyCodeMapsToACaseWithCopy(code: BackendErrorCode) {
        #expect(code.appError != .unknown, "\(code.rawValue) fell through")
    }

    @Test func groupCodesMapToTheirCases() {
        let expected: [String: AppError] = [
            "CONTENT_REJECTED": .contentRejected, "FORBIDDEN": .insufficientRole, "NOT_A_MEMBER": .notAMember,
            "BANNED": .bannedFromGroup, "ACCOUNT_SUSPENDED": .accountSuspended, "TERMS_REQUIRED": .termsRequired,
            "GROUP_NOT_FOUND": .groupNotFound, "MESSAGE_NOT_FOUND": .messageNotFound,
            "REPORT_NOT_FOUND": .reportFailed, "USER_NOT_FOUND": .userNotFound, "GROUP_ID_TAKEN": .groupCreationFailed,
            "GROUP_ID_REUSED": .groupCreationFailed, "GROUP_FULL": .groupFull, "OWNER_CANNOT_LEAVE": .ownerCannotLeave,
            "MEMBER_BANNED": .memberBanned, "MEMBERSHIP_LIMIT": .membershipLimitReached,
            "INVITE_EXPIRED": .inviteExpired, "INVITE_NOT_PENDING": .inviteNotPending,
            "INBOX_ITEM_NOT_FOUND": .inviteNotPending, "ALREADY_MEMBER": .alreadyMember, "CANNOT_INVITE": .cannotInvite,
            "BLOCK_LIMIT": .blockLimitReached, "CONVERSATION_LIMIT": .conversationLimit,
            "REPLY_TARGET_NOT_FOUND": .replyTargetNotFound, "ATTACHMENT_NOT_FOUND": .attachmentNotFound,
            "ATTACHMENT_TOO_LARGE": .attachmentTooLarge, "ATTACHMENT_TYPE_NOT_ALLOWED": .attachmentTypeNotAllowed,
            "ATTACHMENTS_DISABLED": .attachmentsDisabled,
        ]
        for (raw, error) in expected {
            #expect(BackendErrorCode(rawValue: raw)?.appError == error, "\(raw)")
        }
        #expect(APIError.http(status: 403, body: APIErrorBody(code: "TERMS_REQUIRED", message: "m")).appError(fallback: .unknown)
                == .termsRequired)
    }
}
