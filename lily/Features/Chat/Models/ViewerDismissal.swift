import CoreGraphics
import Foundation

/// The attachment viewer's drag to close, as rules. Only a drag that starts more up or down than sideways is the
/// viewer's (sideways is the pager's, or a video's scrubber's), and only its up or down part moves the picture.
/// Letting go closes when that distance, with the throw projected forward for `viewerThrowProjection`, reaches
/// `viewerDismissDistance`: the picture goes back onto its tile in the chat (`ViewerGeometry`). Short of it, it springs
/// back to the middle.
nonisolated enum ViewerDismissal {
    /// Whether a drag starting at `velocity` is the viewer's: more up or down than sideways.
    static func beginsDismissal(velocity: CGSize) -> Bool {
        abs(velocity.height) > abs(velocity.width)
    }

    /// Where the drag would be after the throw, up or down.
    static func projected(drag: CGFloat, velocity: CGFloat) -> CGFloat {
        drag + velocity * DesignTokens.Duration.viewerThrowProjection
    }

    /// Whether letting go closes the viewer: dragged or thrown far enough, up or down.
    static func closes(drag: CGFloat, velocity: CGFloat) -> Bool {
        abs(projected(drag: drag, velocity: velocity)) >= DesignTokens.Layout.viewerDismissDistance
    }
}
