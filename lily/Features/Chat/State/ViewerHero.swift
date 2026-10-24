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
    /// The chat's rows' area in the window, between the top bars and the composer: what of a tile shows in the chat.
    @ObservationIgnored var viewport: CGRect?
    @ObservationIgnored private let thumbnailsByID = NSMapTable<NSString, UIImage>.strongToWeakObjects()
    /// The full pictures decoded for the viewer before it opened, kept until it closes.
    @ObservationIgnored private(set) var preloaded: [String: UIImage] = [:]
    @ObservationIgnored private let logger: (any Logging)?

    init(logger: (any Logging)? = nil) {
        self.logger = logger
    }

    /// Where the tile standing for `ids` is now; `nil` once it left the screen. A move of the tile in the viewer is
    /// logged, since the picture lands where the tile last said it was.
    func place(_ geometry: TileGeometry?, for ids: [String]) {
        for id in ids { tiles[id] = geometry }
        if let shownID, ids.contains(shownID) {
            log("tile of \(shownID) \(geometry.map { "moved to \(Self.describe($0.frame))" } ?? "left the screen")")
        }
    }

    /// Decodes the full picture of `attachment` before the viewer opens, so it opens sharp; waits at most
    /// `viewerPreloadWait`, after which the viewer opens on the thumbnail and the page carries on loading.
    func preload(_ attachment: Attachment, in message: ChatMessage, through loader: AttachmentLoader) async {
        guard attachment.kind == .image, preloaded[attachment.id] == nil else { return }
        let load = AttachmentImageLoad()
        let started = Date.now
        try? await Deadline.within(AppConfig.Chat.viewerPreloadWait) {
            await load.load(attachment, variant: .full, in: message, through: loader)
        }
        // A tap overtaken by another, or a chat left meanwhile, keeps nothing.
        guard !Task.isCancelled else { return }
        preloaded[attachment.id] = load.image
        let waited = Int(Date.now.timeIntervalSince(started) * 1000)
        log("preloaded \(attachment.id): \(load.image == nil ? "not in time" : "sharp") after \(waited) ms")
    }

    /// The viewer closed: its pictures go.
    func forgetPreloaded() {
        preloaded.removeAll()
    }

    /// A line of the viewer's coming and going, at debug: ids and geometry only.
    func log(_ message: String) {
        logger?.debug(.chat, "Viewer \(message)")
    }

    static func describe(_ rect: CGRect?) -> String {
        guard let rect else { return "none" }
        return String(format: "%.0f,%.0f %.0fx%.0f", rect.minX, rect.minY, rect.width, rect.height)
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
