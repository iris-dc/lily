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
}

nonisolated extension DesignTokens.Layout {
    /// A tile in the Explore tournaments carousel: the group tile's width, one row.
    static let tournamentTileWidth: CGFloat = groupTileWidth
    static let tournamentTileHeight: CGFloat = groupTileHeight
    /// The bar under a tournament's facts: the capacity bar's height, one look for every "how full" bar.
    static let entriesBarHeight: CGFloat = capacityBarHeight
    /// One round of a bracket (L2's `BracketView`), and one match cell in it.
    static let bracketColumnWidth: CGFloat = 220
    static let matchCellHeight: CGFloat = 72
}
