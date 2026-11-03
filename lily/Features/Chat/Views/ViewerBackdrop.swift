import SwiftUI

/// The black of one layer of the viewer, where `ViewerLayer.backdrop` puts it, at `ViewerGeometry.backdropOpacity`: the
/// cover's above the composer line and the chat's below it make one black behind the moving picture.
struct ViewerBackdrop: View {
    let hero: ViewerHero
    let layer: ViewerLayer

    var body: some View {
        GeometryReader { proxy in
            let space = proxy.frame(in: .global)
            if let region = layer.backdrop(viewport: hero.viewport, screen: space, moving: hero.moving != nil) {
                Color.black
                    .opacity(ViewerGeometry.backdropOpacity(progress: hero.progress, drag: hero.drag))
                    .frame(width: region.width, height: region.height)
                    .offset(x: region.minX - space.minX, y: region.minY - space.minY)
            }
        }
        .ignoresSafeArea()
    }
}
