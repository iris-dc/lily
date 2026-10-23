import SwiftUI

/// What a chat and its viewer share for the viewer's coming and going: where each gallery tile is and the thumbnail it
/// shows, so the viewer opens out of the tile with a picture already on it and closes back into it, and which
/// attachment is in the viewer, whose tile shows the accent meanwhile. Tiles write their places on every layout pass
/// and scroll, so those stay out of observation; only the attachment in the viewer redraws a tile. Thumbnails are held
/// weakly: each is the tile's own, and a long room would otherwise keep every decoded one it ever showed.
@Observable @MainActor
final class ViewerHero {
    /// The attachment on screen in the viewer; `nil` while it is closed.
    var shownID: String?
    @ObservationIgnored private(set) var tiles: [String: TileGeometry] = [:]
    @ObservationIgnored private let thumbnailsByID = NSMapTable<NSString, UIImage>.strongToWeakObjects()

    /// Where the tile standing for `ids` is now; `nil` once it left the screen.
    func place(_ geometry: TileGeometry?, for ids: [String]) {
        for id in ids { tiles[id] = geometry }
    }

    func noteThumbnail(_ image: UIImage?, for id: String) {
        if let image {
            thumbnailsByID.setObject(image, forKey: id as NSString)
        } else {
            thumbnailsByID.removeObject(forKey: id as NSString)
        }
    }

    /// The thumbnail the tile of `id` shows, while the tile holds it.
    func thumbnail(for id: String) -> UIImage? {
        thumbnailsByID.object(forKey: id as NSString)
    }
}

extension EnvironmentValues {
    /// The chat's `ViewerHero`; `nil` where no viewer opens (a preview, an unsent bubble).
    @Entry var viewerHero: ViewerHero?
}
