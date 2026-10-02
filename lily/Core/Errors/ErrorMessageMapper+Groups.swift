import Foundation

/// Copy for groups and moderation (the chat's is in `ErrorMessageMapper+Chat.swift`); `message(for:)` routes exactly
/// those cases here. In its own file because the mapper's type body is at SwiftLint's limit.
nonisolated extension ErrorMessageMapper {
    static func groupMessage(for error: AppError) -> ErrorMessage {
        switch error {
        case .groupsUnavailable:
            ErrorMessage(title: "Groups unavailable", body: "We couldn't load groups right now. Pull to refresh in a moment.")
        case .groupNotFound:
            ErrorMessage(title: "Group not found", body: "This group is no longer available.")
        case .groupFull:
            ErrorMessage(title: "Group is full", body: "This group has reached its member limit.")
        case .notAMember:
            ErrorMessage(title: "Not a member", body: "You're not in this group. Join it first.")
        case .bannedFromGroup:
            ErrorMessage(title: "You can't join this group", body: "An admin has removed you from this group.")
        case .memberBanned:
            ErrorMessage(title: "Already banned", body: "This person is banned from the group. Unban them from the banned list.")
        case .ownerCannotLeave:
            ErrorMessage(title: "You own this group", body: "Owners can't leave their group. Delete it instead.")
        case .insufficientRole:
            ErrorMessage(title: "Not allowed", body: "Only admins can do that in this group.")
        case .membershipLimitReached:
            ErrorMessage(title: "Too many groups",
                         body: "You can be in at most \(AppConfig.Groups.maxMemberships) groups. Leave one to join another.")
        default:
            groupWriteMessage(for: error)
        }
    }

    static func moderationMessage(for error: AppError) -> ErrorMessage {
        switch error {
        case .reportFailed:
            ErrorMessage(title: "Couldn't send your report", body: "Please try again in a moment.")
        case .blockLimitReached:
            ErrorMessage(title: "Block list full", body: "You've blocked the maximum number of people. Unblock someone first.")
        case .userNotFound:
            ErrorMessage(title: "Person not found", body: "This account is no longer available.")
        case .accountSuspended:
            ErrorMessage(title: "Account suspended",
                         body: "This account was suspended for breaking the terms of use. "
                             + "Contact \(AppConfig.Moderation.supportEmail).")
        case .termsRequired:
            ErrorMessage(title: "Please accept the updated terms", body: "Accept the terms of use to continue.")
        default:
            unknownMessage
        }
    }

    /// Creating and editing; split from `groupMessage` to keep each switch under the complexity limit.
    private static func groupWriteMessage(for error: AppError) -> ErrorMessage {
        switch error {
        case .groupCreationFailed:
            ErrorMessage(title: "Couldn't create your group", body: "Check the details and try again in a moment.")
        case .groupActionFailed:
            ErrorMessage(title: "Couldn't update the group", body: "Please try again in a moment.")
        case .contentRejected:
            ErrorMessage(title: "Please rephrase", body: "That text contains words or links we don't allow.")
        default:
            inviteMessage(for: error)
        }
    }

    /// Invites, sent from a group and answered from the inbox.
    private static func inviteMessage(for error: AppError) -> ErrorMessage {
        switch error {
        case .inviteExpired:
            ErrorMessage(title: "Invite expired", body: "Ask to be invited again.")
        case .inviteUnavailable:
            ErrorMessage(title: "Couldn't send the invite", body: "Please try again in a moment.")
        case .inboxUnavailable:
            ErrorMessage(title: "Couldn't load your notifications", body: "Pull down to try again in a moment.")
        case .inviteActionFailed:
            ErrorMessage(title: "Couldn't answer the invite", body: "Please try again in a moment.")
        case .inviteNotPending:
            ErrorMessage(title: "This invite was already answered", body: "There is nothing left to do here.")
        case .alreadyMember:
            ErrorMessage(title: "They're already in this group", body: "No invite needed.")
        case .cannotInvite:
            ErrorMessage(title: "This person can't be invited", body: "They were banned from this group.")
        default:
            unknownMessage
        }
    }
}
