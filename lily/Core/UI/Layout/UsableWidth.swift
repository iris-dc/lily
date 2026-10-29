import SwiftUI

/// The width of a view that lies inside the window's horizontal safe area. Safe-area insets are anchored to the
/// window's edges, not the view's, so a view may start beside the region an inset covers (the Chats detail column
/// beside the iPad's floating sidebar: a frame from x 310 and a leading inset of 310 that overlaps none of it) or
/// under it (a scroll view running under a floating panel); `width - leading - trailing` is right only in the second
/// case and squeezes a column beside the sidebar to a third of its width. The frame in the window (`.global`) says how
/// much of the leading inset the view overlaps; the trailing inset needs the window's width too (`\.windowWidth`) and
/// is taken to overlap the view whole while that is unknown. Only the part of the view inside an inset's region counts,
/// never a part beyond the window's edge: a screen sliding off during a back swipe is not covered by anything, and
/// counting what had left the window shrank every bubble and picture of the chat as it went. The width is the frame's
/// own: `GeometryProxy.size` and `frame(in: .global)` agree without a scaling ancestor, and the app has none.
nonisolated enum UsableWidth {
    static func of(leading: CGFloat, trailing: CGFloat, frameInWindow: CGRect, windowWidth: CGFloat?) -> CGFloat {
        let width = frameInWindow.width
        let coveredLeading = overlap(of: frameInWindow, from: 0, to: leading)
        let coveredTrailing: CGFloat
        if let windowWidth {
            coveredTrailing = overlap(of: frameInWindow, from: windowWidth - trailing, to: windowWidth)
        } else {
            coveredTrailing = min(trailing, width)
        }
        return max(width - coveredLeading - coveredTrailing, 0)
    }

    /// How much of `frame` lies between `start` and `end` across.
    private static func overlap(of frame: CGRect, from start: CGFloat, to end: CGFloat) -> CGFloat {
        max(min(frame.maxX, end) - max(frame.minX, start), 0)
    }
}

extension EnvironmentValues {
    /// The window's width as the root measured it (`layoutModeProvider()`); `nil` above the root or before its first
    /// layout. An environment value rather than a named coordinate space on the root: `bounds(of:)` answers `nil` from
    /// inside a split view's detail column, which is hosted apart from the root.
    @Entry var windowWidth: CGFloat?
    /// The window's full height, safe areas included, as the root measured it; `nil` above the root or before its first
    /// layout. What `ContentScreen` sizes its aurora by, so a sheet's background keeps one size while the sheet's does not.
    @Entry var windowHeight: CGFloat?
}
