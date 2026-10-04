import Foundation

/// Identifiers of the Groups, chat and moderation screens; mirrored by hand in `lilyUITests` like the rest.
nonisolated extension AccessibilityIdentifiers {
    /// The Discover screen's type dropdown; the Explore carousel and its "See all".
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
    /// The room's "more" menu and its one item, Clear chat or Delete chat.
    static let chatMore = "chat-more"
    static let chatClear = "chat-clear"
    /// The composer's reply preview (a container; its children keep their own identifiers) and the X that drops it.
    static let chatReplyPreview = "chat-reply-preview"
    static let chatReplyCancel = "chat-reply-cancel"
    /// Fields and actions of the create-group sheet; `createGroup` is the event form's group row.
    static let createGroupName = "create-group-name"
    static let createGroupDescription = "create-group-description"
    static let createGroupVisibility = "create-group-visibility"
    static let createGroupSubmit = "create-group-submit"
    static let createGroupCancel = "create-group-cancel"
    static let createGroup = "create-group"
    /// The terms sheet; the report sheet's identifiers are in `AccessibilityIdentifiers+Moderation.swift`.
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

    /// The quote inside a reply's bubble, keyed by the original's id.
    static func messageQuote(id: String) -> String {
        "message-quote-\(id)"
    }

    static func memberRow(_ userID: String) -> String {
        "member-row-\(userID)"
    }

    /// The invite-people sheet: its search field, a candidate's row and the row's Invite button.
    static let inviteSearch = "invite-search"

    static func inviteCandidate(_ userID: String) -> String {
        "invite-candidate-\(userID)"
    }

    static func inviteSend(_ userID: String) -> String {
        "invite-send-\(userID)"
    }
}
