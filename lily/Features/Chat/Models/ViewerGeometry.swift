import SwiftUI

/// Where a gallery tile is in the window and how it is rounded: what the viewer opens out of and closes back into.
nonisolated struct TileGeometry: Equatable, Sendable {
    var frame: CGRect
    var radii: RectangleCornerRadii
}

/// Where the viewer draws its picture at one moment of its coming and going, as rules: `progress` 0 is the picture
/// fitted to its page, 1 is the picture on its tile, filling it as the tile crops it and rounded like it; the drag moves
/// it up or down only, at full size. The picture fills `rect`, so the crop follows the rect's shape on the way; every
/// value is linear in `progress`, so the frames the `ViewerMoveDriver` writes stay on the path. Without a tile to land on, the
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
        rect = Self.mix(start, tile.frame, progress)
        radii = RectangleCornerRadii(topLeading: tile.radii.topLeading * progress,
                                     bottomLeading: tile.radii.bottomLeading * progress,
                                     bottomTrailing: tile.radii.bottomTrailing * progress,
                                     topTrailing: tile.radii.topTrailing * progress)
        opacity = 1
    }

    /// What of the moving picture the viewer's cover draws, over the bars: everything above the composer line (the
    /// chat's `viewport`, the rows' area between the top bars and the composer, ends there); at the top the whole screen
    /// while the picture is fitted or dragged, the viewport's edge from `viewerViewportCutProgress` on the way to the tile,
    /// linear in between, so a tile partly under a bar keeps that part's picture behind it (`shownPart`) and the moving
    /// picture comes out from behind the bar on the way in and goes back behind it on the way out. Below the line the
    /// chat draws the picture itself, under the composer (`underComposer`).
    static func clip(viewport: CGRect?, screen: CGRect, progress: CGFloat) -> CGRect {
        guard let viewport else { return screen }
        let cut = min(1, max(0, progress / DesignTokens.Layout.viewerViewportCutProgress))
        let top = mix(screen, viewport, cut)
        return CGRect(x: top.minX, y: top.minY, width: top.width, height: viewport.maxY - top.minY)
    }

    /// What of the moving picture the chat draws, under the composer: the screen below the composer line, where the
    /// composer's glass covers the picture as it covers the tile's part there, and the composer itself fades
    /// (`chromeOpacity`). `nil` without a viewport, or when nothing lies below the line.
    static func underComposer(viewport: CGRect?, screen: CGRect) -> CGRect? {
        guard let viewport, viewport.maxY < screen.maxY else { return nil }
        return CGRect(x: screen.minX, y: viewport.maxY, width: screen.width, height: screen.maxY - viewport.maxY)
    }

    /// The part of a tile the chat's `viewport` shows, in the tile's own coordinates: what the viewer's picture stands
    /// for, so the slot it leaves covers only that, and a part under the composer or a bar keeps its picture behind them
    /// for the whole move. The whole tile without a viewport; `nil` when none of it shows.
    static func shownPart(of tile: CGRect, in viewport: CGRect?) -> CGRect? {
        let local = CGRect(origin: .zero, size: tile.size)
        guard let viewport else { return local }
        let shown = tile.intersection(viewport)
        guard !shown.isNull, !shown.isEmpty else { return nil }
        return shown.offsetBy(dx: -tile.minX, dy: -tile.minY)
    }

    /// Where the viewer's cover draws its black: the screen above the composer line while the chat draws the picture
    /// and the black below it, the whole screen otherwise.
    static func overComposer(viewport: CGRect?, screen: CGRect) -> CGRect {
        guard let under = underComposer(viewport: viewport, screen: screen) else { return screen }
        return CGRect(x: screen.minX, y: screen.minY, width: screen.width, height: under.minY - screen.minY)
    }

    /// The black behind the picture and the controls over it: gone on the tile, and fading as the picture is dragged
    /// over `viewerFadeDistance`, so the chat shows through.
    static func backdropOpacity(progress: CGFloat, drag: CGFloat) -> Double {
        let dragged = min(1, abs(drag) / DesignTokens.Layout.viewerFadeDistance)
        return (1 - Double(progress)) * (1 - Double(dragged))
    }

    /// The composer over the picture's way: gone while the viewer is open, whole with the picture on its tile, coming
    /// back as the black goes, so the picture's part under it shows through until the chat is back.
    static func chromeOpacity(progress: CGFloat, drag: CGFloat) -> Double {
        1 - backdropOpacity(progress: progress, drag: drag)
    }

    /// The largest rect of `aspectRatio` centred in `bounds`, as `scaledToFit` lays a picture out; `bounds` itself when
    /// the ratio is unknown.
    static func fit(_ aspectRatio: CGFloat?, in bounds: CGRect) -> CGRect {
        aspect(aspectRatio, in: bounds, covering: false)
    }

    /// The smallest rect of `aspectRatio` covering `bounds`, centred, as `scaledToFill` lays a picture out; `bounds`
    /// itself when the ratio is unknown.
    static func fill(_ aspectRatio: CGFloat?, in bounds: CGRect) -> CGRect {
        aspect(aspectRatio, in: bounds, covering: true)
    }

    /// The rect of `aspectRatio` centred in `bounds` that the bounds contain, or, `covering`, that contains them: bounds
    /// wider than the ratio bind a fitted rect by their height and a covering one by their width, and the other way round.
    private static func aspect(_ aspectRatio: CGFloat?, in bounds: CGRect, covering: Bool) -> CGRect {
        guard let aspectRatio, aspectRatio > 0, bounds.width > 0, bounds.height > 0 else { return bounds }
        let wide = bounds.width / bounds.height > aspectRatio
        let size = wide != covering
            ? CGSize(width: bounds.height * aspectRatio, height: bounds.height)
            : CGSize(width: bounds.width, height: bounds.width / aspectRatio)
        return CGRect(x: bounds.midX - size.width / 2,
                      y: bounds.midY - size.height / 2,
                      width: size.width,
                      height: size.height)
    }

    /// `from` moved toward `to` by `progress`: 0 is `from`, 1 is `to`.
    static func mix(_ from: CGFloat, _ to: CGFloat, _ progress: CGFloat) -> CGFloat {
        from + (to - from) * progress
    }

    /// Each edge of `from` moved toward `to` by `progress`.
    static func mix(_ from: CGRect, _ to: CGRect, _ progress: CGFloat) -> CGRect {
        CGRect(x: mix(from.minX, to.minX, progress),
               y: mix(from.minY, to.minY, progress),
               width: mix(from.width, to.width, progress),
               height: mix(from.height, to.height, progress))
    }
}
