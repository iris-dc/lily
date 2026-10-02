import Foundation

/// Replying. The quote rides on the draft, so `send()` carries it and the fresh draft after a send has none; the unsent
/// bubble shows it; a tap on a quote brings the original on screen, loading older pages while it lies before the
/// history held. Whether a quoted original is gone is this device's knowledge: the backend never rewrites a stored
/// quote, so the room's tombstones decide.
extension ChatViewModel {
    /// The message the composer answers; `nil` while the draft is a plain message.
    var replyTarget: ReplyQuote? { draft.replyTo }

    /// Any member's message that is neither deleted nor a system row.
    func canReply(to message: ChatMessage) -> Bool {
        !message.isDeleted && !message.isSystem
    }

    /// Quotes `row` in the composer, named after its sender as the roster knows them now.
    func startReply(to row: MessageRow) {
        guard canReply(to: row.message) else { return }
        draft.replyTo = ReplyQuote(quoting: row.message, senderName: row.senderName)
    }

    func cancelReply() {
        draft.replyTo = nil
    }

    func quoteIsDeleted(_ quote: ReplyQuote) -> Bool {
        room.isDeleted(id: quote.messageId)
    }

    /// Brings the quoted original into the history held, loading the page before while it lies before the oldest
    /// message here, at most `AppConfig.Chat.maxReplyLookupPages` of them; answers whether it is here to scroll to.
    func revealQuoted(id: String) async -> Bool {
        var pagesLoaded = 0
        while liesBeforeHistory(id), pagesLoaded < AppConfig.Chat.maxReplyLookupPages {
            guard await loadOlder() else { break }
            pagesLoaded += 1
        }
        let found = room.contains(id: id)
        if !found { logger.debug(.chat, "Quoted message \(id) not within \(pagesLoaded) older pages of group \(group.id)") }
        return found
    }

    /// A reply refused because its original is gone keeps its bubble, failed, as a plain message: Retry sends it
    /// without the quote.
    func dropReply(from clientMessageID: String) {
        guard let index = pending.firstIndex(where: { $0.clientMessageID == clientMessageID }) else { return }
        pending[index] = pending[index].droppingReply()
    }

    private func liesBeforeHistory(_ id: String) -> Bool {
        guard hasOlder, let oldest = room.oldestID else { return false }
        return id < oldest
    }
}
