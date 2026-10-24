import Foundation

/// Identifiers of polls and pins; mirrored by hand in `lilyUITests` like the rest.
nonisolated extension AccessibilityIdentifiers {
    /// The "+" menu's Poll item, and the creation sheet's fields and Send.
    static let chatAttachPoll = "chat-attach-poll"
    static let pollQuestionField = "poll-question"
    static let pollAddOption = "poll-add-option"
    static let pollAnonymousToggle = "poll-anonymous"
    static let pollMultipleToggle = "poll-multiple"
    static let pollSend = "poll-send"
    static func pollOptionField(_ index: Int) -> String { "poll-option-field-\(index)" }
    /// In a poll bubble: an option, the Vote button of a poll with multiple answers, the total, View votes.
    static func pollOption(_ index: Int) -> String { "poll-option-\(index)" }
    static let pollVote = "poll-vote"
    static let pollTotal = "poll-total"
    static let pollVoters = "poll-voters"
    static let pollVotersSheet = "poll-voters-sheet"
    /// The long-press menu's items.
    static let messageRetractVote = "message-retract-vote"
    static let messagePin = "message-pin"
    static let messageUnpin = "message-unpin"
    /// The bar of pinned messages at the top of the chat (a button), and its unpin.
    static let pinnedBar = "chat-pinned-bar"
    static let pinnedBarUnpin = "chat-pinned-bar-unpin"
}
