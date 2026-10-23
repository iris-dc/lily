import SwiftUI

/// Where a gallery tile is in the window and how it is rounded: what the viewer opens out of and closes back into.
nonisolated struct TileGeometry: Equatable, Sendable {
    var frame: CGRect
    var radii: RectangleCornerRadii
}

/// Where the viewer draws its picture at one moment of its coming and going, as rules: `progress` 0 is the picture
/// fitted to its page, 1 is the picture on its tile, filling it as the tile crops it and rounded like it; the drag moves
/// it up or down only, at full size. The picture fills `rect`, so the crop follows the rect's shape on the way; every
/// value is linear in `progress`, so an animation of it draws each frame of the way. Without a tile to land on, the
/// picture fades instead. Pure, so the frames can be checked without a view.
nonisolated struct ViewerGeometry: Equatable, Sendable {
    var rect: CGRect
    var radii: RectangleCornerRadii
    var opacity: Double

    /// - Parameters:
    ///   - page: where the page lays its picture out, fitted, in the same coordinates as `tile`.
    ///   - aspectRatio: width over height of the picture; it fills the page when unknown.
    ///   - tile: the tile the picture opens out of and closes into; `nil` fades instead.
    ///   - progress: 0 fitted to the page, 1 on the tile.
    ///   - drag: how far up (negative) or down the picture is dragged.
    init(page: CGRect, aspectRatio: CGFloat?, tile: TileGeometry?, progress: CGFloat, drag: CGFloat) {
        let start = Self.fit(aspectRatio, in: page).offsetBy(dx: 0, dy: drag)
        guard let tile else {
            rect = start
            radii = RectangleCornerRadii(topLeading: 0, bottomLeading: 0, bottomTrailing: 0, topTrailing: 0)
            opacity = 1 - Double(progress)
            return
        }
        rect = CGRect(x: Self.mix(start.minX, tile.frame.minX, progress),
                      y: Self.mix(start.minY, tile.frame.minY, progress),
                      width: Self.mix(start.width, tile.frame.width, progress),
                      height: Self.mix(start.height, tile.frame.height, progress))
        radii = RectangleCornerRadii(topLeading: tile.radii.topLeading * progress,
                                     bottomLeading: tile.radii.bottomLeading * progress,
                                     bottomTrailing: tile.radii.bottomTrailing * progress,
                                     topTrailing: tile.radii.topTrailing * progress)
        opacity = 1
    }

    /// The black behind the picture and the controls over it: gone on the tile, and fading as the picture is dragged
    /// over `viewerFadeDistance`, so the chat shows through.
    static func backdropOpacity(progress: CGFloat, drag: CGFloat) -> Double {
        let dragged = min(1, abs(drag) / DesignTokens.Layout.viewerFadeDistance)
        return (1 - Double(progress)) * (1 - Double(dragged))
    }

    /// The largest rect of `aspectRatio` centred in `bounds`, as `scaledToFit` lays a picture out; `bounds` itself when
    /// the ratio is unknown.
    static func fit(_ aspectRatio: CGFloat?, in bounds: CGRect) -> CGRect {
        guard let aspectRatio, aspectRatio > 0, bounds.width > 0, bounds.height > 0 else { return bounds }
        let size = bounds.width / bounds.height > aspectRatio
            ? CGSize(width: bounds.height * aspectRatio, height: bounds.height)
            : CGSize(width: bounds.width, height: bounds.width / aspectRatio)
        return CGRect(x: bounds.midX - size.width / 2,
                      y: bounds.midY - size.height / 2,
                      width: size.width,
                      height: size.height)
    }

    private static func mix(_ from: CGFloat, _ to: CGFloat, _ progress: CGFloat) -> CGFloat {
        from + (to - from) * progress
    }
}
