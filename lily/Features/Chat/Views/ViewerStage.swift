import SwiftUI

/// The chat's side of the viewer's coming and going, laid over the transcript under the composer: below the composer
/// line it draws the black the viewer's cover draws above it (`ViewerBackdrop`), and the moving picture's part there
/// (`ViewerMovingPicture`, `.underComposer`), so a tile partly under the composer opens and closes whole, its part under
/// the glass included, while the composer itself fades with the move (`ViewerGeometry.chromeOpacity`). Nothing while
/// the viewer is closed.
struct ViewerStage: View {
    let hero: ViewerHero

    var body: some View {
        if hero.moving != nil {
            ZStack {
                ViewerBackdrop(hero: hero, layer: .underComposer)
                ViewerMovingPicture(hero: hero, layer: .underComposer)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}
