import Testing
@testable import lily

/// Every `AppError` once, payload cases sampled.
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
        .pollsNotAllowed, .notAPoll, .pollAnonymous, .voteFailed, .notPinnable, .tooManyPins, .pinFailed,
        .reportFailed, .blockLimitReached, .userNotFound, .accountSuspended, .termsRequired,
        .profileUnavailable, .conversationFailed, .conversationLimit,
        .tournamentsUnavailable, .tournamentNotFound, .tournamentCreationFailed, .tournamentUpdateFailed, .tournamentActionFailed,
        .registrationClosed, .tournamentFull, .alreadyEntered, .teamFull, .entryNotFound, .notOrganizer, .tournamentLocked,
        .notEnoughEntries, .notInMatch, .matchNotReady, .matchNotFound, .drawNotAllowed, .tournamentLimit,
        .tournamentMembershipLimit, .inviteeAlreadyEntered, .cannotInviteToTournament, .feedbackFailed,
        .unknown,
    ]

    /// Exhaustive on purpose: a new `AppError` case fails to compile here, the reminder to add it to `all` too.
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
             .attachmentsDisabled, .attachmentUploadFailed, .attachmentUnavailable, .pollsNotAllowed, .notAPoll,
             .pollAnonymous, .voteFailed, .notPinnable, .tooManyPins, .pinFailed, .reportFailed, .blockLimitReached,
             .userNotFound, .accountSuspended, .termsRequired, .profileUnavailable, .conversationFailed,
             .conversationLimit, .tournamentsUnavailable, .tournamentNotFound, .tournamentCreationFailed,
             .tournamentUpdateFailed, .tournamentActionFailed, .registrationClosed, .tournamentFull, .alreadyEntered,
             .teamFull, .entryNotFound, .notOrganizer, .tournamentLocked, .notEnoughEntries, .notInMatch,
             .matchNotReady, .matchNotFound, .drawNotAllowed, .tournamentLimit, .tournamentMembershipLimit,
             .inviteeAlreadyEntered, .cannotInviteToTournament, .feedbackFailed, .unknown:
            break
        }
    }
}

struct AppErrorCasesTests {
    /// A case listed twice would stand in for one left out.
    @Test func everyCaseIsListedOnce() {
        #expect(Set(AppErrorCases.all.map { "\($0)" }).count == AppErrorCases.all.count)
    }
}
