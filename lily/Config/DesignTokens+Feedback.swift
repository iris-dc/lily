import Foundation

nonisolated extension DesignTokens.Symbols {
    /// The contact row on Profile; an outline, like the tab glyphs.
    static let feedback = "envelope"
    /// The thanks state once a message went out.
    static let feedbackSent = "paperplane"
}

nonisolated extension DesignTokens.Layout {
    /// The message field grows with the text up to this many lines before it scrolls.
    static let feedbackMessageLines = 4...10
}
