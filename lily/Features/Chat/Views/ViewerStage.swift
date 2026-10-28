import SwiftUI

/// The chat's side of the viewer's coming and going, laid over the transcript under the composer: below the composer
/// line it draws the black the viewer's cover draws above it, and the moving picture's part there
/// (`ViewerMovingPicture`, `.underComposer`), so a tile partly under the composer opens and closes whole, its part under
/// the glass included, while the composer itself fades with the move (`ViewerGeometry.chromeOpacity`). Nothing while
/// the viewer is closed.
struct ViewerStage: View {
    let hero: ViewerHero

    var body: some View {
        if hero.moving != nil {
            GeometryReader { proxy in
                let space = proxy.frame(in: .global)
                if let region = ViewerGeometry.underComposer(viewport: hero.viewport, screen: space) {
                    Color.black
                        .opacity(ViewerGeometry.backdropOpacity(progress: hero.progress, drag: hero.drag))
                        .frame(width: region.width, height: region.height)
                        .offset(x: region.minX - space.minX, y: region.minY - space.minY)
                }
                ViewerMovingPicture(hero: hero, layer: .underComposer)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}
