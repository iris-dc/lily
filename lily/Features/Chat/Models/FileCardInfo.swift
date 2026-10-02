import Foundation
import UniformTypeIdentifiers

/// What a file card shows, for a stored file and for a picked one alike: the name (the kind's word when the sender
/// gave none), the size in the reader's units, and a glyph for the type, which comes from the content type when the
/// system knows it and from the name's extension otherwise. Pure, so the copy is tested without a view.
nonisolated struct FileCardInfo: Equatable, Sendable {
    let displayName: String
    let sizeBytes: Int
    let type: UTType?

    init(fileName: String?, contentType: String, sizeBytes: Int) {
        displayName = fileName.flatMap { $0.isEmpty ? nil : $0 } ?? AppBranding.Chat.Attachments.fileFallbackName
        self.sizeBytes = sizeBytes
        type = Self.type(contentType: contentType, fileName: fileName)
    }

    /// The first glyph of `DesignTokens.Symbols.fileGlyphs` the type conforms to, else the plain document.
    var symbol: String {
        guard let type else { return DesignTokens.Symbols.file }
        return DesignTokens.Symbols.fileGlyphs.first { type.conforms(to: $0.type) }?.symbol ?? DesignTokens.Symbols.file
    }

    /// "812 kB", "1.5 MB": the file style, in `locale` (the reader's by default; tests pin one).
    func sizeText(locale: Locale = .autoupdatingCurrent) -> String {
        Int64(sizeBytes).formatted(.byteCount(style: .file).locale(locale))
    }

    /// A type the content type names, unless it is the generic octet stream, which only the extension can refine.
    static func type(contentType: String, fileName: String?) -> UTType? {
        if let type = UTType(mimeType: contentType), type != .data { return type }
        guard let fileName, let dot = fileName.lastIndex(of: "."), dot < fileName.index(before: fileName.endIndex) else {
            return nil
        }
        return UTType(filenameExtension: String(fileName[fileName.index(after: dot)...]))
    }
}

/// The length a video tile shows in its corner: "0:12", "2:05".
nonisolated enum VideoCaption {
    static func duration(_ seconds: Int) -> String {
        Duration.seconds(seconds).formatted(.time(pattern: .minuteSecond))
    }
}
