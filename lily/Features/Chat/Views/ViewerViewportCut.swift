import SwiftUI

extension View {
    /// Cuts the viewer's moving picture to `ViewerGeometry.clip` at `progress`, worked out on every frame of a move.
    func viewerViewportCut(progress: CGFloat, viewport: CGRect?, screen: CGRect) -> some View {
        modifier(ViewerViewportCut(progress: progress, viewport: viewport, screen: screen))
    }
}

/// Animatable, so SwiftUI hands it each frame's `progress`: the cut is not linear in it, and a mask sized in the
/// viewer's body would be interpolated straight from its start to its end.
private struct ViewerViewportCut: ViewModifier, Animatable {
    var progress: CGFloat
    let viewport: CGRect?
    let screen: CGRect

    nonisolated var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let clip = ViewerGeometry.clip(viewport: viewport, screen: screen, progress: progress)
        content.mask(alignment: .topLeading) {
            Rectangle()
                .frame(width: clip.width, height: clip.height)
                .offset(x: clip.minX, y: clip.minY)
        }
    }
}
