import SwiftUI

/// The width of a view that lies inside the window's horizontal safe area. Safe-area insets are anchored to the
/// window's edges, so a view may start beside the region they cover (the Chats detail column beside the floating
/// sidebar on an iPad: a frame from x 310 and a leading inset of 310 that overlaps none of it) or under it (a scroll
/// view running under a floating panel); `width - leading - trailing` is right only in the second case and squeezed
/// the iPad bubbles to a third of the column (seen 2026-10-08). The view's frame in the window (`.global`) says how
/// much of the leading inset it overlaps; the trailing inset needs the window's width too (`\.windowWidth`, published
/// by `layoutModeProvider()`), and is taken to overlap the view whole while that is unknown.
nonisolated enum UsableWidth {
    static func of(width: CGFloat,
                   leading: CGFloat,
                   trailing: CGFloat,
                   frameInWindow: CGRect,
                   windowWidth: CGFloat?) -> CGFloat {
        let coveredLeading = min(max(leading - frameInWindow.minX, 0), width)
        let coveredTrailing: CGFloat
        if let windowWidth {
            coveredTrailing = min(max(frameInWindow.maxX - (windowWidth - trailing), 0), width)
        } else {
            coveredTrailing = min(trailing, width)
        }
        return max(width - coveredLeading - coveredTrailing, 0)
    }
}

extension EnvironmentValues {
    /// The window's width as the root measured it (`layoutModeProvider()`); `nil` above the root or before its first
    /// layout. A named coordinate space on the root was tried for the same purpose and was not found from inside a
    /// split view's detail column, which is hosted apart from the root.
    @Entry var windowWidth: CGFloat?
}
