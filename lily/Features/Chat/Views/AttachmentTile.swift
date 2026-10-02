import SwiftUI

/// A picture filling its tile, cropped to it, or its stand-in: a spinner while it loads, a faint glyph when it could
/// not be loaded. Flexible, so the gallery or the strip sizes it; a plain fill, never glass, like the bubble it sits in.
struct AttachmentTile: View {
    let image: UIImage?
    let isLoading: Bool
    /// The glyph shown when the picture could not be loaded; a video tile names its own.
    var placeholderSymbol = DesignTokens.Symbols.photoLibrary

    var body: some View {
        Color.lilySurface
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else if isLoading {
                    ProgressView()
                } else {
                    Image(systemName: placeholderSymbol)
                        .font(.title2)
                        .foregroundStyle(.secondary)
                        .opacity(DesignTokens.Opacity.attachmentPlaceholderGlyph)
                }
            }
            .clipped()
    }
}

/// A picture from a file on the device (a picked draft's thumbnail, in the strip and in the unsent bubble), decoded
/// off the main actor; a spinner while the preparer still works on it.
struct LocalImage: View {
    let url: URL
    var isPreparing = false
    @State private var image: UIImage?
    @State private var failed = false

    private struct LoadKey: Hashable {
        let url: URL
        let isPreparing: Bool
    }

    var body: some View {
        AttachmentTile(image: image, isLoading: isPreparing || (image == nil && !failed))
            .task(id: LoadKey(url: url, isPreparing: isPreparing)) {
                guard !isPreparing else { return }
                image = await ImageFile.load(url)
                failed = image == nil
            }
    }
}

/// Reads and decodes a picture file where it will not stall the main actor.
enum ImageFile {
    static func load(_ url: URL) async -> UIImage? {
        guard let image = UIImage(contentsOfFile: url.path()) else { return nil }
        return await image.byPreparingForDisplay() ?? image
    }
}
