import CoreGraphics
import Foundation

/// The attachment viewer's drag to close, as rules: a drag's axis is read once it has moved
/// `viewerDragLockDistance`; a vertical one carries the page away (down or up), a horizontal one is the pager's, or a
/// video's scrubber's, unless the viewer holds a single picture, when it carries the page too. The page fades and
/// shrinks with the distance, and letting go closes the viewer past `viewerDismissDistance`, or when thrown past
/// `viewerThrowDistance`; short of both it settles back.
nonisolated enum ViewerDismissal {
    enum Axis: Equatable, Sendable {
        case vertical
        case horizontal
    }

    /// A drag as it goes: its axis once read, and how far it carries the page.
    struct Drag: Equatable, Sendable {
        private(set) var axis: Axis?
        private(set) var carried = CGSize.zero

        /// Follows the finger: reads the axis once, then carries the page along the axes that carry it.
        mutating func follow(_ translation: CGSize, carriesHorizontally: Bool) {
            if axis == nil { axis = ViewerDismissal.axis(of: translation) }
            guard let axis, axis == .vertical || carriesHorizontally else { return }
            carried = translation
        }

        /// The whole drag, read at once: what letting go judges.
        static func reading(_ translation: CGSize, carriesHorizontally: Bool) -> Drag {
            var drag = Drag()
            drag.follow(translation, carriesHorizontally: carriesHorizontally)
            return drag
        }
    }

    /// The axis a drag goes along, once it has moved far enough to tell; the one it moved more along.
    static func axis(of translation: CGSize) -> Axis? {
        guard distance(translation) >= DesignTokens.Layout.viewerDragLockDistance else { return nil }
        return abs(translation.height) >= abs(translation.width) ? .vertical : .horizontal
    }

    /// Whether a horizontal drag carries the page: only a single picture's, with no page to turn and no scrubber.
    static func carriesHorizontally(pages: Int, isPicture: Bool) -> Bool {
        pages <= 1 && isPicture
    }

    /// How far toward closing the drag has gone, 0 to 1.
    static func progress(of translation: CGSize) -> Double {
        min(1, distance(translation) / DesignTokens.Layout.viewerDismissDistance)
    }

    /// Whether letting go closes the viewer: dragged far enough, or thrown far enough.
    static func closes(translation: CGSize, predictedEnd: CGSize) -> Bool {
        distance(translation) >= DesignTokens.Layout.viewerDismissDistance
            || distance(predictedEnd) >= DesignTokens.Layout.viewerThrowDistance
    }

    private static func distance(_ size: CGSize) -> CGFloat {
        (size.width * size.width + size.height * size.height).squareRoot()
    }
}
