import Testing
@testable import lily

/// Every `AppError` once, the four with payloads sampled; `listed(_:)` is the reminder that a new case belongs here.
enum AppErrorCases {
    static let all: [AppError] = [
        .authCancelled, .authFailed(provider: .apple), .providerUnavailable(provider: .apple), .invalidCredentials,
        .emailTaken, .emailNotConfirmed, .invalidConfirmationCode, .tooManyAttempts,
        .sessionExpired, .rateLimited(retryAfter: nil), .network, .eventsUnavailable, .eventNotFound, .eventFull,
        .alreadyJoined, .notAParticipant, .hostCannotLeave, .tryAgain, .participationFailed, .eventCreationFailed,
        .notHost, .capacityTooLow, .eventUpdateFailed,
        .groupsUnavailable, .groupNotFound, .groupFull, .notAMember, .bannedFromGroup, .memberBanned, .ownerCannotLeave,
        .insufficientRole, .membershipLimitReached, .groupCreationFailed, .groupActionFailed, .contentRejected,
        .inviteExpired, .inviteUnavailable, .inboxUnavailable, .inviteActionFailed, .inviteNotPending, .alreadyMember,
        .cannotInvite, .chatUnavailable, .messageSendFailed, .messageNotFound, .replyTargetNotFound,
        .attachmentNotFound, .attachmentTooLarge(caps: .group), .attachmentTypeNotAllowed, .attachmentsDisabled,
        .attachmentUploadFailed,
        .attachmentUnavailable,
        .reportFailed, .blockLimitReached, .userNotFound, .accountSuspended, .termsRequired,
        .profileUnavailable, .conversationFailed, .conversationLimit,
        .tournamentsUnavailable, .tournamentNotFound, .tournamentCreationFailed, .tournamentUpdateFailed, .tournamentActionFailed,
        .registrationClosed, .tournamentFull, .alreadyEntered, .teamFull, .entryNotFound, .notOrganizer, .tournamentLocked,
        .notEnoughEntries, .notInMatch, .matchNotReady, .matchNotFound, .drawNotAllowed, .tournamentLimit,
        .inviteeAlreadyEntered, .cannotInviteToTournament, .feedbackFailed,
        .unknown,
    ]

    /// Names every case with no `default`: a case added to `AppError` fails to compile here until `all` lists it too.
    static func listed(_ error: AppError) {
        switch error {
        case .authCancelled, .authFailed, .providerUnavailable, .invalidCredentials, .emailTaken, .emailNotConfirmed,
             .invalidConfirmationCode, .tooManyAttempts, .sessionExpired, .rateLimited, .network, .eventsUnavailable,
             .eventNotFound, .eventFull, .alreadyJoined, .notAParticipant, .hostCannotLeave, .tryAgain,
             .participationFailed, .eventCreationFailed, .notHost, .capacityTooLow, .eventUpdateFailed,
             .groupsUnavailable, .groupNotFound, .groupFull, .notAMember, .bannedFromGroup, .memberBanned,
             .ownerCannotLeave, .insufficientRole, .membershipLimitReached, .groupCreationFailed, .groupActionFailed,
             .contentRejected, .inviteExpired, .inviteUnavailable, .inboxUnavailable, .inviteActionFailed,
             .inviteNotPending, .alreadyMember, .cannotInvite, .chatUnavailable, .messageSendFailed, .messageNotFound,
             .replyTargetNotFound, .attachmentNotFound, .attachmentTooLarge, .attachmentTypeNotAllowed,
             .attachmentsDisabled, .attachmentUploadFailed, .attachmentUnavailable, .reportFailed, .blockLimitReached,
             .userNotFound, .accountSuspended, .termsRequired, .profileUnavailable, .conversationFailed,
             .conversationLimit, .tournamentsUnavailable, .tournamentNotFound, .tournamentCreationFailed,
             .tournamentUpdateFailed, .tournamentActionFailed, .registrationClosed, .tournamentFull, .alreadyEntered,
             .teamFull, .entryNotFound, .notOrganizer, .tournamentLocked, .notEnoughEntries, .notInMatch,
             .matchNotReady, .matchNotFound, .drawNotAllowed, .tournamentLimit, .inviteeAlreadyEntered,
             .cannotInviteToTournament, .feedbackFailed, .unknown:
            break
        }
    }
}

struct AppErrorCasesTests {
    /// A case listed twice would stand in for one left out, so the list is as long as the set of its cases.
    @Test func everyCaseIsListedOnce() {
        #expect(Set(AppErrorCases.all.map { "\($0)" }).count == AppErrorCases.all.count)
    }
}
