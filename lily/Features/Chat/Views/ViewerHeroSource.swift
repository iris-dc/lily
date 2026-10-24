import SwiftUI

extension View {
    /// A gallery tile the viewer opens out of and closes into: it reports where it is in the window for every attachment
    /// it stands for (the "+N" tile stands for the hidden ones too) and shows the accent while one of them is in the
    /// viewer, over the part the chat shows only (`ViewerGeometry.shownPart`): a part under the composer keeps its
    /// picture behind the glass, so nothing changes there when the picture lands.
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
                if let hero, let shown = hero.shownID, ids.contains(shown) { slot(viewport: hero.viewport) }
            }
            .onGeometryChange(for: CGRect.self, of: { $0.frame(in: .global) }, action: { frame in
                hero?.place(TileGeometry(frame: frame, radii: radii), for: ids)
            })
            .onDisappear { hero?.place(nil, for: ids) }
    }

    private func slot(viewport: CGRect?) -> some View {
        GeometryReader { proxy in
            if let part = ViewerGeometry.shownPart(of: proxy.frame(in: .global), in: viewport) {
                Color.lilyAccent
                    .frame(width: part.width, height: part.height)
                    .offset(x: part.minX, y: part.minY)
            }
        }
    }
}
