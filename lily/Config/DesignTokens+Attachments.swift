import Foundation
import UniformTypeIdentifiers

nonisolated extension DesignTokens.Symbols {
    /// The attach menu's "+", its items, and the glyphs of the media kinds.
    static let attach = "plus.circle"
    static let photoLibrary = "photo.on.rectangle"
    static let camera = "camera"
    static let file = "doc"
    static let play = "play.fill"
    /// A video tile whose thumbnail could not be loaded.
    static let videoPlaceholder = "film"
    /// The X on a picked picture in the strip.
    static let remove = "xmark.circle.fill"
    /// Sharing the full picture from the viewer.
    static let share = "square.and.arrow.up"
    /// On a file card whose bytes are not on the device yet.
    static let download = "arrow.down.circle"
    /// The glyph of a file card by what the file conforms to, first match wins; `file` for everything else.
    static let fileGlyphs: [(type: UTType, symbol: String)] = [
        (.pdf, "doc.richtext"),
        (.archive, "doc.zipper"),
        (.spreadsheet, "tablecells"),
        (.presentation, "rectangle.on.rectangle"),
        (.audio, "waveform"),
        (.movie, "film"),
        (.image, "photo"),
        (.text, "doc.text"),
    ]
}

nonisolated extension DesignTokens.Layout {
    /// Side of a picked picture's tile in the strip above the composer.
    static let attachmentThumb: CGFloat = 72
    /// Gap between the tiles of a gallery in a bubble.
    static let gallerySpacing: CGFloat = 2
    /// A single picture in a bubble is never taller than this; a tall one gets narrower instead.
    static let galleryMaxHeight: CGFloat = 320
    /// Width of a gallery as a share of the list: with the bubble's padding and another sender's avatar column it
    /// stays inside `bubbleMaxWidthFraction` on every iPhone width.
    static let galleryWidthFraction: CGFloat = 0.6
    /// Stroke of the upload progress ring on a strip tile.
    static let progressRingWidth: CGFloat = 3
    /// Diameter of the progress ring and of the X on a strip tile.
    static let stripBadgeSize: CGFloat = 22
    /// How far a picture in the viewer may be zoomed in.
    static let viewerMaxZoom: CGFloat = 4
    /// The play badge over a video tile in a bubble, and its smaller sibling on a strip tile.
    static let playBadgeSize: CGFloat = 44
    static let stripPlayBadgeSize: CGFloat = 24
    /// The play glyph's point size as a share of its badge.
    static let playGlyphFraction: CGFloat = 0.45
    /// The ring the player and a file card fill while the bytes download.
    static let downloadRingSize: CGFloat = 44
    /// A picked file's chip in the strip is this wide (as tall as the picture tiles beside it).
    static let fileChipWidth: CGFloat = 168
    /// The type glyph's square on a file card, and how many lines the name may take.
    static let fileIconSize: CGFloat = 40
    static let fileNameLines = 2
}

nonisolated extension DesignTokens.Opacity {
    /// The scrim over the last tile of a gallery that hides more pictures, under the "+N".
    static let galleryOverflowScrim: Double = 0.45
    /// The glyph on a picture's placeholder while it loads.
    static let attachmentPlaceholderGlyph: Double = 0.35
    /// The dark circle behind the strip's X, so it reads on any picture.
    static let stripBadgeBacking: Double = 0.6
    /// The dark circle behind a play badge and the dark capsule behind a video's duration.
    static let playBadgeBacking: Double = 0.55
    /// The size caption under a file's name, quieter than the name.
    static let fileCaption: Double = 0.75
}
