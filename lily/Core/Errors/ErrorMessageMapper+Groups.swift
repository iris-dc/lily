import Foundation

/// Copy for groups and moderation (the chat's is in `ErrorMessageMapper+Chat.swift`); `message(for:)` routes exactly
/// those cases here. In its own file because the mapper's type body is at SwiftLint's limit.
nonisolated extension ErrorMessageMapper {
    static func groupMessage(for error: AppError) -> ErrorMessage {
        switch error {
        case .groupsUnavailable:
            ErrorMessage(title: localized("Groups unavailable"),
                         body: localized("We couldn't load groups right now. Pull to refresh in a moment."))
        case .groupNotFound:
            ErrorMessage(title: localized("Group not found"), body: localized("This group is no longer available."))
        case .groupFull:
            ErrorMessage(title: localized("Group is full"), body: localized("This group has reached its member limit."))
        case .notAMember:
            ErrorMessage(title: localized("Not a member"), body: localized("You're not in this group. Join it first."))
        case .bannedFromGroup:
            ErrorMessage(title: localized("You can't join this group"),
                         body: localized("An admin has removed you from this group."))
        case .memberBanned:
            ErrorMessage(title: localized("Already banned"),
                         body: localized("This person is banned from the group. Unban them from the banned list."))
        case .ownerCannotLeave:
            ErrorMessage(title: localized("You own this group"),
                         body: localized("Owners can't leave their group. Delete it instead."))
        case .insufficientRole:
            ErrorMessage(title: localized("Not allowed"), body: localized("Only admins can do that in this group."))
        case .membershipLimitReached:
            membershipLimitMessage
        default:
            groupWriteMessage(for: error)
        }
    }

    static func moderationMessage(for error: AppError) -> ErrorMessage {
        switch error {
        case .reportFailed:
            ErrorMessage(title: localized("Couldn't send your report"), body: localized("Please try again in a moment."))
        case .blockLimitReached:
            ErrorMessage(title: localized("Block list full"),
                         body: localized("You've blocked the maximum number of people. Unblock someone first."))
        case .userNotFound:
            ErrorMessage(title: localized("Person not found"), body: localized("This account is no longer available."))
        case .accountSuspended:
            accountSuspendedMessage
        case .termsRequired:
            ErrorMessage(title: localized("Please accept the updated terms"),
                         body: localized("Accept the terms of use to continue."))
        default:
            unknownMessage
        }
    }

    /// The two bodies that name a value from the config.
    private static var membershipLimitMessage: ErrorMessage {
        let limit = AppConfig.Groups.maxMemberships
        return ErrorMessage(title: localized("Too many groups"),
                            body: localized("You can be in at most \(limit) groups. Leave one to join another."))
    }

    private static var accountSuspendedMessage: ErrorMessage {
        let support = AppConfig.Moderation.supportEmail
        return ErrorMessage(title: localized("Account suspended"),
                            body: localized("This account was suspended for breaking the terms of use. Contact \(support)."))
    }

    /// Creating and editing; split from `groupMessage` to keep each switch under the complexity limit.
    private static func groupWriteMessage(for error: AppError) -> ErrorMessage {
        switch error {
        case .groupCreationFailed:
            ErrorMessage(title: localized("Couldn't create your group"),
                         body: localized("Check the details and try again in a moment."))
        case .groupActionFailed:
            ErrorMessage(title: localized("Couldn't update the group"), body: localized("Please try again in a moment."))
        case .contentRejected:
            ErrorMessage(title: localized("Please rephrase"),
                         body: localized("That text contains words or links we don't allow."))
        default:
            inviteMessage(for: error)
        }
    }

    /// Invites, sent from a group and answered from the inbox.
    private static func inviteMessage(for error: AppError) -> ErrorMessage {
        switch error {
        case .inviteExpired:
            ErrorMessage(title: localized("Invite expired"), body: localized("Ask to be invited again."))
        case .inviteUnavailable:
            ErrorMessage(title: localized("Couldn't send the invite"), body: localized("Please try again in a moment."))
        case .inboxUnavailable:
            ErrorMessage(title: localized("Couldn't load your notifications"),
                         body: localized("Pull down to try again in a moment."))
        case .inviteActionFailed:
            ErrorMessage(title: localized("Couldn't answer the invite"), body: localized("Please try again in a moment."))
        case .inviteNotPending:
            ErrorMessage(title: localized("This invite was already answered"),
                         body: localized("There is nothing left to do here."))
        case .alreadyMember:
            ErrorMessage(title: localized("They're already in this group"), body: localized("No invite needed."))
        case .cannotInvite:
            ErrorMessage(title: localized("This person can't be invited"), body: localized("They were banned from this group."))
        default:
            unknownMessage
        }
    }
}
