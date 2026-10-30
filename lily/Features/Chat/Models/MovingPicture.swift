import UIKit

/// The picture the viewer draws on its way in and out, by itself, where `ViewerGeometry` puts it between `page` (where
/// its page lays it out, in the window; `nil` before the page's first layout, which the screen stands in for) and its
/// tile (`ViewerHero.tiles[id]`, or the `landing` once it closes).
nonisolated struct MovingPicture {
    let id: String
    let image: UIImage
    let page: CGRect?
}
