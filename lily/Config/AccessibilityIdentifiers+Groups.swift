import Foundation

/// Identifiers of the Groups and chat screens; mirrored by hand in `lilyUITests` like the rest. The terms and report
/// sheets have theirs in `AccessibilityIdentifiers+Moderation.swift`.
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
    /// The menu's Report group item.
    static let groupReport = "group-report"
    static let membersList = "members-list"
    /// Chat: the message list, the composer field and its send button, and the title button that opens the group.
    static let chatList = "chat-list"
    static let chatComposer = "chat-composer"
    static let chatSend = "chat-send"
    static let chatTitle = "chat-title"
    /// The room's "more" menu and its one item, Clear chat or Delete chat.
    static let chatMore = "chat-more"
    static let chatClear = "chat-clear"
    /// The Report and Block items of a bubble's long-press menu.
    static let messageReport = "message-report"
    static let messageBlock = "message-block"
    /// The composer's reply preview (a container; its children keep their own identifiers) and the X that drops it.
    static let chatReplyPreview = "chat-reply-preview"
    static let chatReplyCancel = "chat-reply-cancel"
    /// Fields and actions of the create-group sheet; `createGroup` is the event form's group row.
    static let createGroupName = "create-group-name"
    static let createGroupDescription = "create-group-description"
    static let createGroupVisibility = "create-group-visibility"
    /// The group form's place: its name field and the row that opens the map.
    static let createGroupLocationName = "create-group-location-name"
    static let createGroupPickOnMap = "create-group-pick-on-map"
    static let createGroupSubmit = "create-group-submit"
    static let createGroupCancel = "create-group-cancel"
    static let createGroup = "create-group"

    static func groupRow(_ id: String) -> String {
        "group-row-\(id)"
    }

    /// A bubble whose message carries a client id: the caller's always (stable across the optimistic -> stored swap)
    /// and, from the backend, every member's, since Laurel sends clientMessageId on every member message.
    static func message(clientID: String) -> String {
        "message-client-\(clientID)"
    }

    /// A bubble whose message carries no client id (the mock's other senders).
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
