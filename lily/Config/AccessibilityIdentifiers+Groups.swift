import Foundation

/// Identifiers of the Groups, chat and moderation screens; mirrored by hand in `lilyUITests` like the rest.
nonisolated extension AccessibilityIdentifiers {
    /// Home's "Join with code" button; the Discover screen's type dropdown; the Explore carousel and its "See all".
    static let groupsJoinCode = "groups-join-code"
    static let groupsTypeFilter = "groups-type-filter"
    static let groupCarousel = "group-carousel"
    static let groupsSeeAll = "groups-see-all"
    /// Group detail actions, its Events | Members picker and the toolbar menu.
    static let groupJoin = "group-join"
    static let groupOpenChat = "group-open-chat"
    static let groupInvite = "group-invite"
    static let groupCreateEvent = "group-create-event"
    static let groupMore = "group-more"
    static let groupSection = "group-section"
    static let groupLeave = "group-leave"
    static let membersList = "members-list"
    /// Chat: the message list, the composer field and its send button, and the title button that opens the group.
    static let chatList = "chat-list"
    static let chatComposer = "chat-composer"
    static let chatSend = "chat-send"
    static let chatTitle = "chat-title"
    /// Fields and actions of the create-group sheet; `createGroup` is the event form's group row.
    static let createGroupName = "create-group-name"
    static let createGroupDescription = "create-group-description"
    static let createGroupVisibility = "create-group-visibility"
    static let createGroupSubmit = "create-group-submit"
    static let createGroupCancel = "create-group-cancel"
    static let createGroup = "create-group"
    /// Invite sheets: the code field and redeem button, sharing and copying a code.
    static let inviteCodeField = "invite-code-field"
    /// Continue in the code sheet; `inviteRedeem` is the join button of the preview that follows.
    static let inviteContinue = "invite-continue"
    static let inviteRedeem = "invite-redeem"
    /// The inline reason when the backend refused the code (invalid or expired).
    static let inviteRefusal = "invite-refusal"
    static let inviteShare = "invite-share"
    static let inviteCopy = "invite-copy"
    /// Report sheet and terms sheet.
    static let reportReason = "report-reason"
    static let reportSubmit = "report-submit"
    static let termsAccept = "terms-accept"

    static func groupRow(_ id: String) -> String {
        "group-row-\(id)"
    }

    /// A bubble is keyed by its client id when it has one (stable across the optimistic -> confirmed swap).
    static func message(clientID: String) -> String {
        "message-client-\(clientID)"
    }

    static func message(id: String) -> String {
        "message-\(id)"
    }

    static func memberRow(_ userID: String) -> String {
        "member-row-\(userID)"
    }
}
