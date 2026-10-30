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
