import SwiftUI

extension View {
    /// A gallery tile the viewer opens out of and closes into: it reports where it is in the window for every attachment
    /// it stands for (the "+N" tile stands for the hidden ones too) and shows the accent while one of them is in the
    /// viewer.
    func viewerHeroSource(for ids: [String], radii: RectangleCornerRadii) -> some View {
        modifier(ViewerHeroSource(ids: ids, radii: radii))
    }
}

private struct ViewerHeroSource: ViewModifier {
    let ids: [String]
    let radii: RectangleCornerRadii
    @Environment(\.viewerHero) private var hero

    func body(content: Content) -> some View {
        content
            .overlay {
                if let shown = hero?.shownID, ids.contains(shown) { Color.lilyAccent }
            }
            .onGeometryChange(for: CGRect.self, of: { $0.frame(in: .global) }, action: { frame in
                hero?.place(TileGeometry(frame: frame, radii: radii), for: ids)
            })
            .onDisappear { hero?.place(nil, for: ids) }
    }
}
