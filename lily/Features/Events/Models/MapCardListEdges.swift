import CoreGraphics

/// Whether the map's card list has cards beyond its top or bottom edge, and how many wait below: what its fades and
/// its "+2 more" pill show. Read off the scroll geometry rather than which cards count as visible, so it holds at
/// accessibility type sizes, where one card can be taller than the list.
nonisolated struct MapCardListEdges: Equatable, Sendable {
    let hasMoreAbove: Bool
    let hasMoreBelow: Bool

    static let none = MapCardListEdges(hasMoreAbove: false, hasMoreBelow: false)

    init(hasMoreAbove: Bool, hasMoreBelow: Bool) {
        self.hasMoreAbove = hasMoreAbove
        self.hasMoreBelow = hasMoreBelow
    }

    /// `offset` is how far the content's top has scrolled past the list's top; a point of slack absorbs rounding.
    init(offset: CGFloat, contentHeight: CGFloat, containerHeight: CGFloat) {
        let slack = DesignTokens.Layout.mapCardEdgeSlack
        hasMoreAbove = offset > slack
        hasMoreBelow = contentHeight - containerHeight - offset > slack
    }

    /// The whole cards after the last one in view, so the pill names only cards still to come: none once the last
    /// card is in view, even while its bottom is cut, and none for a lone card. Before the scroll view first reports,
    /// the first card is the one in view.
    static func cardsBelow<ID: Equatable>(in ids: [ID], visible: [ID]) -> Int {
        let last = ids.lastIndex { visible.contains($0) } ?? 0
        return max(0, ids.count - 1 - last)
    }
}
