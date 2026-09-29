import Foundation

nonisolated extension DesignTokens.Symbols {
    static let groups = "person.3"
    static let publicGroup = "globe"
    static let privateGroup = "lock"
    static let chat = "bubble.left.and.bubble.right"
    static let send = "paperplane.fill"
    /// Inviting a person directly (no links or codes).
    static let invite = "person.badge.plus"
    /// The invite sheet's name search.
    static let search = "magnifyingglass"
    static let report = "flag"
    static let block = "hand.raised"
    static let admin = "star.fill"
    static let owner = "crown.fill"
    static let more = "ellipsis.circle"
    static let info = "info.circle"
    static let failed = "exclamationmark.circle"
    static let edit = "pencil"
    static let leave = "rectangle.portrait.and.arrow.right"
    static let delete = "trash"
    static let copy = "doc.on.doc"
}

nonisolated extension DesignTokens.Layout {
    static let avatarSmall: CGFloat = 28
    static let avatarMedium: CGFloat = 40
    /// Initials in an avatar are this share of its diameter, so every size reads the same.
    static let avatarInitialsFraction: CGFloat = 0.4
    /// A chat bubble grows to this share of the list's width before it wraps.
    static let bubbleMaxWidthFraction: CGFloat = 0.78
    static let unreadDotSize: CGFloat = 8
    static let groupBadgeMaxWidth: CGFloat = 140
    /// A tile in the Explore groups carousel, and how many rows of them scroll together.
    static let groupTileWidth: CGFloat = 250
    static let groupTileHeight: CGFloat = 64
    static let groupCarouselRows = 2
    /// Lines the preview card gives its title and caption once the row has become a column at accessibility sizes.
    static let accessibilityPreviewLines = 2
    /// Description lines on a Discover card.
    static let cardDescriptionLines = 2
    /// Within this many points of the end the chat list counts as scrolled to the bottom and follows new messages.
    static let atBottomThreshold: CGFloat = 24
    /// Fixed slot above the oldest loaded message; the older-page spinner shows in it, so loading never shifts the rows.
    static let olderPageSlotHeight: CGFloat = 28
    /// Scrolling to within this many points of the top asks for the page before the oldest loaded message.
    static let olderPageTriggerDistance: CGFloat = 200
    /// Text inset inside a chat bubble.
    static let bubbleHorizontalPadding: CGFloat = DesignTokens.Spacing.md
    static let bubbleVerticalPadding: CGFloat = DesignTokens.Spacing.sm
}

nonisolated extension DesignTokens.Radius {
    static let bubble: CGFloat = 18
}

nonisolated extension DesignTokens.Opacity {
    /// A message that is still on its way to the backend.
    static let pendingMessage: Double = 0.6
}
