import SwiftUI

/// The attachment viewer's drag to close, as rules. Only a drag that starts more up or down than sideways is the
/// viewer's (sideways is the pager's, or a video's scrubber's); the page then follows the finger, fading and shrinking
/// with how far up or down it has gone. Letting go closes when that distance, with the throw projected forward for
/// `viewerThrowProjection`, reaches `viewerDismissDistance`: the page carries on off the screen from the speed it was let
/// go with (`flyOutMotion`), coming to rest past the edge. Short of it the page springs back.
nonisolated enum ViewerDismissal {
    /// Whether a drag starting at `velocity` is the viewer's: more up or down than sideways.
    static func beginsDismissal(velocity: CGSize) -> Bool {
        abs(velocity.height) > abs(velocity.width)
    }

    /// How far toward closing the drag has gone, 0 to 1: up or down only.
    static func progress(of translation: CGSize) -> Double {
        min(1, abs(translation.height) / DesignTokens.Layout.viewerDismissDistance)
    }

    /// Where the drag would be after the throw, up or down.
    static func projectedHeight(of translation: CGSize, velocity: CGSize) -> CGFloat {
        translation.height + velocity.height * DesignTokens.Duration.viewerThrowProjection
    }

    /// Whether letting go closes the viewer: dragged or thrown far enough, up or down.
    static func closes(translation: CGSize, velocity: CGSize) -> Bool {
        abs(projectedHeight(of: translation, velocity: velocity)) >= DesignTokens.Layout.viewerDismissDistance
    }

    /// Where the closing page goes: off the screen of `height` the way it was thrown, keeping its sideways place.
    static func flyOut(from translation: CGSize, velocity: CGSize, height: CGFloat) -> CGSize {
        let direction: CGFloat = projectedHeight(of: translation, velocity: velocity) < 0 ? -1 : 1
        return CGSize(width: translation.width, height: direction * height)
    }

    /// How the closing page flies to `target`: the time an even slowing from the speed it was let go with needs for the
    /// rest of the way (it starts at twice its average speed), within `viewerFlyOutDuration`, and a curve that starts
    /// at that speed whatever the bounds made of the time. Only speed toward the target counts: a page let go at rest,
    /// or with the finger moving back, starts from rest.
    static func flyOutMotion(from translation: CGSize, to target: CGSize, velocity: CGSize) -> FlyOutMotion {
        let bounds = DesignTokens.Duration.viewerFlyOutDuration
        let way = target.height - translation.height
        let distance = abs(way)
        let speed = max(0, way < 0 ? -velocity.height : velocity.height)
        guard speed > 0, distance > 0 else { return FlyOutMotion(duration: bounds.upperBound, startSlope: 0) }
        let duration = min(max(2 * distance / speed, bounds.lowerBound), bounds.upperBound)
        return FlyOutMotion(duration: duration, startSlope: min(speed * duration / distance, FlyOutMotion.steepestStart))
    }
}

/// The closing page's flight: how long it lasts and how fast it starts, as a multiple of its average speed.
nonisolated struct FlyOutMotion: Equatable, Sendable {
    /// Beyond it the curve's first control point would rise past its end and the page would overshoot and come back.
    static let steepestStart: Double = 3

    var duration: TimeInterval
    var startSlope: Double

    /// A cubic whose control points sit at thirds of the time, so its time runs evenly: it starts at `startSlope` and
    /// comes to rest at its end, never overshooting within `steepestStart`.
    var curve: UnitCurve {
        .bezier(startControlPoint: UnitPoint(x: 1.0 / 3, y: startSlope / 3),
                endControlPoint: UnitPoint(x: 2.0 / 3, y: 1))
    }
}
