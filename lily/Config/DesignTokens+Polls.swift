import Foundation

/// Polls and pins: their symbols and the poll bubble's measures.
nonisolated extension DesignTokens.Symbols {
    static let poll = "chart.bar.xaxis"
    static let pin = "pin"
    static let unpin = "pin.slash"
    static let retractVote = "arrow.uturn.backward"
    static let pollChoice = "circle"
    static let pollChosen = "checkmark.circle.fill"
    static let pollTick = "square"
    static let pollTicked = "checkmark.square.fill"
    static let addOption = "plus.circle.fill"
    static let removeOption = "minus.circle.fill"
    static let dismissPin = "xmark"
}

nonisolated extension DesignTokens.Layout {
    /// The results bar under each option of a poll the caller voted in.
    static let pollBarHeight: CGFloat = 4
    /// A poll fills the bubble's share of the list, so its options and bars have room.
    static let pollMinWidth: CGFloat = 220
    /// The percentage column of the results, so the options line up.
    static let pollShareWidth: CGFloat = 40
    /// The pinned bar's accent stripe, one segment per pin.
    static let pinStripeWidth: CGFloat = 2
    static let pinStripeSpacing: CGFloat = 2
    /// The stripe's height: the bar's two lines, its title and the quote.
    static let pinStripeHeight: CGFloat = 34
}

nonisolated extension DesignTokens.Opacity {
    /// A results bar's track, under its fill.
    static let pollBarTrack = 0.18
    /// The pinned bar's segments of the pins not shown.
    static let pinStripeIdle = 0.36
    /// Captions on the caller's accent bubble, where `.secondary` would turn grey.
    static let secondaryOnAccent = 0.75
}
