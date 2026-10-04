import Foundation

nonisolated extension DesignTokens.Symbols {
    /// A tournament: its room on Chats, its carousel, the "+" menu item.
    static let tournament = "trophy"
    static let bracket = "rectangle.split.3x1"
    static let standings = "list.number"
    /// A team entry on the Players segment; an individual entry draws the person's avatar instead.
    static let team = "person.2.fill"
    static let captain = "flag.fill"
    static let format = "point.3.connected.trianglepath.dotted"
    static let registrationCloses = "hourglass"
    /// A disputed match, on its cell and on the chat's row; the match sheet's walkover menu; a scheduled match's time.
    static let disputed = "exclamationmark.triangle.fill"
    static let walkover = "person.fill.xmark"
    static let scheduled = "calendar.badge.clock"
}

nonisolated extension DesignTokens.Layout {
    /// A tile in the Explore tournaments carousel: the group tile's width, one row.
    static let tournamentTileWidth: CGFloat = groupTileWidth
    static let tournamentTileHeight: CGFloat = groupTileHeight
    /// The bar under a tournament's facts: the capacity bar's height, one look for every "how full" bar.
    static let entriesBarHeight: CGFloat = capacityBarHeight
    /// One round of a bracket (`BracketView`), one match cell in it, and the gaps between columns and cells; a later
    /// round's cell is centred on the two cells that feed it (`BracketLayout.slotHeight`).
    static let bracketColumnWidth: CGFloat = 220
    static let matchCellHeight: CGFloat = 72
    static let bracketColumnSpacing: CGFloat = DesignTokens.Spacing.lg
    static let bracketCellSpacing: CGFloat = DesignTokens.Spacing.md
    /// The two score fields of the match sheet.
    static let scoreFieldWidth: CGFloat = 88
    /// The number columns of the standings table; the name takes the rest.
    static let standingsRankWidth: CGFloat = 22
    static let standingsStatWidth: CGFloat = 22
    static let standingsDifferenceWidth: CGFloat = 36
    static let standingsPointsWidth: CGFloat = 32
}

nonisolated extension DesignTokens.Opacity {
    /// The side that lost a decided match, faded against the winner in ink.
    static let matchLoser: Double = 0.45
    /// The accent wash behind the caller's row of the standings, and the accent border of the caller's own match.
    static let standingsHighlight: Double = 0.14
    static let ownMatchStroke: Double = 0.6
}
