import Foundation

/// Polls and pins: their symbols and the poll bubble's measures.
nonisolated extension DesignTokens.Symbols {
    static let poll = "chart.bar.xaxis"
    static let pin = "pin"
    static let unpin = "pin.slash"
    static let retractVote = "arrow.uturn.backward"
    /// A pill's ring, and the ring ticked: the caller's pick, or their tick before Vote in a poll with several answers.
    static let pollChoice = "circle"
    static let pollChosen = "checkmark.circle.fill"
    static let addOption = "plus.circle.fill"
    static let removeOption = "minus.circle.fill"
    static let dismissPin = "xmark"
}

nonisolated extension DesignTokens.Layout {
    /// An option's pill: one height whether it shows a ring or its share, so a vote moves no row.
    static let pollOptionMinHeight: CGFloat = 36
    /// The share at a pill's trailing edge ("100%"), reserved before it shows so the text never shifts.
    static let pollShareWidth: CGFloat = 40
    /// The bubble's last line (the voters' count, Vote or View votes): one height with or without a button.
    static let pollFooterHeight: CGFloat = 32
    /// The pinned bar's accent stripe, one segment per pin.
    static let pinStripeWidth: CGFloat = 2
    static let pinStripeSpacing: CGFloat = 2
    /// The stripe's height: the bar's two lines, its title and the quote.
    static let pinStripeHeight: CGFloat = 34
}

nonisolated extension DesignTokens.Radius {
    /// An option's pill, under the bubble's radius as the quote is, rounder than the quote for its height.
    static let pollPill: CGFloat = 14
}

nonisolated extension DesignTokens.Opacity {
    /// A pill's track (ink on the surface bubble, white on the caller's) and the share filling it: the accent on the
    /// surface, the deep maroon on the caller's accent, where a white fill left white text unreadable.
    static let pollTrack = 0.08
    static let pollTrackOnAccent = 0.16
    static let pollFill = 0.4
    static let pollFillOnAccent = 0.6
    /// A pill while pressed.
    static let pollPressed = 0.6
    /// The pinned bar's segments of the pins not shown.
    static let pinStripeIdle = 0.36
    /// Captions on the caller's accent bubble, where `.secondary` would turn grey.
    static let secondaryOnAccent = 0.75
}
