import SwiftUI

/// The radii of a gallery tile: its outer corners follow the gallery's frame, inset by the frame's width, and the
/// others, which meet another tile, are `galleryInnerCornerRadius`. The grid draws each tile with them and the viewer
/// lands a closing picture on the same shape.
nonisolated enum GalleryTileShape {
    static func radii(at index: Int, in layout: GalleryLayout, galleryRadius: CGFloat) -> RectangleCornerRadii {
        radii(of: layout.outerCorners(of: index), galleryRadius: galleryRadius)
    }

    static func radii(of corners: TileCorners, galleryRadius: CGFloat) -> RectangleCornerRadii {
        let outer = max(0, galleryRadius - DesignTokens.Layout.galleryOutlineWidth)
        let inner = DesignTokens.Layout.galleryInnerCornerRadius
        return RectangleCornerRadii(topLeading: corners.contains(.topLeading) ? outer : inner,
                                    bottomLeading: corners.contains(.bottomLeading) ? outer : inner,
                                    bottomTrailing: corners.contains(.bottomTrailing) ? outer : inner,
                                    topTrailing: corners.contains(.topTrailing) ? outer : inner)
    }
}
