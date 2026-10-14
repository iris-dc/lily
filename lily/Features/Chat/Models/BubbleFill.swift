import Foundation

/// Whether a bubble's attachments are the bubble. Pictures and videos alone, with no words and no quote, stand alone:
/// no fill, no padding, clipped to the bubble's own corner radius. A file card, words, a quote or a kind this build
/// does not know keep the fill. One rule for the stored (`MessageBubble`) and the unsent (`PendingMessageBubble`)
/// bubble, read by `BubbleContent`.
nonisolated enum BubbleFill {
    static func standsAlone(kinds: [AttachmentKind], hasText: Bool, hasQuote: Bool) -> Bool {
        !kinds.isEmpty && kinds.allSatisfy(\.isMedia) && !hasText && !hasQuote
    }
}
