import SwiftUI

/// Which side of the composer line a layer draws of the viewer's moving picture.
nonisolated enum ViewerLayer: Sendable {
    /// The viewer's cover, over the bars: everything above the composer line (`ViewerGeometry.clip`).
    case overBars
    /// The chat, under the composer: everything below the line (`ViewerGeometry.underComposer`).
    case underComposer

    /// The part of the screen this layer draws, in the screen's coordinates; `nil` when nothing of it.
    func window(viewport: CGRect?, screen: CGRect, progress: CGFloat) -> CGRect? {
        switch self {
        case .overBars: ViewerGeometry.clip(viewport: viewport, screen: screen, progress: progress)
        case .underComposer: ViewerGeometry.underComposer(viewport: viewport, screen: screen)
        }
    }
}

/// The viewer's picture drawn by itself where `ViewerGeometry` puts it between its page and its tile, in the window's
/// coordinates, on its way in and out and while dragged; `layer` says which side of the composer line this copy draws,
/// the other side being the other layer's. Both read the same `ViewerHero` move, so the two halves are one picture on
/// every frame. A `Canvas` the size of the layer's window draws the picture's part in it, filling and rounding the
/// rect as the tile does: a positioned `Image` under `mask` or `clipped()` was drawn whole below the composer line once
/// the picture was dragged, whatever the clip's frame said. Nothing to touch or to read aloud: the pager behind it
/// holds the gestures and the pages' labels.
struct ViewerMovingPicture: View {
    let hero: ViewerHero
    let layer: ViewerLayer

    var body: some View {
        GeometryReader { proxy in
            if let moving = hero.moving, let tile = hero.tiles[moving.id] {
                picture(moving, tile: tile, space: proxy.frame(in: .global))
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    @ViewBuilder private func picture(_ moving: MovingPicture, tile: TileGeometry, space: CGRect) -> some View {
        let toLocal = { (rect: CGRect) in rect.offsetBy(dx: -space.minX, dy: -space.minY) }
        let screen = CGRect(origin: .zero, size: space.size)
        let size = moving.image.size
        let aspectRatio = size.height > 0 ? size.width / size.height : nil
        let geometry = ViewerGeometry(page: toLocal(moving.page ?? space),
                                      aspectRatio: aspectRatio,
                                      tile: TileGeometry(frame: toLocal(hero.landing ?? tile.frame), radii: tile.radii),
                                      progress: hero.progress,
                                      drag: hero.drag)
        if let window = layer.window(viewport: hero.viewport.map(toLocal), screen: screen, progress: hero.progress),
           window.intersects(geometry.rect) {
            Canvas { context, _ in
                context.translateBy(x: -window.minX, y: -window.minY)
                context.clip(to: Path(roundedRect: geometry.rect, cornerRadii: geometry.radii))
                context.draw(Image(uiImage: moving.image), in: ViewerGeometry.fill(aspectRatio, in: geometry.rect))
            }
            .frame(width: window.width, height: window.height)
            .offset(x: window.minX, y: window.minY)
        }
    }
}
