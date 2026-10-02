import Foundation
import Testing
import UniformTypeIdentifiers
@testable import lily

/// What a file card and a video tile say: the name or its stand-in, the size in the reader's units, the glyph for the
/// type (from the content type, else the extension), and a video's length.
struct FileAttachmentCardTests {
    private let octetStream = "application/octet-stream"

    private func info(_ fileName: String?, _ contentType: String = "application/pdf", bytes: Int = 1) -> FileCardInfo {
        FileCardInfo(fileName: fileName, contentType: contentType, sizeBytes: bytes)
    }

    @Test func theSizeReadsInFileUnits() {
        let locale = Locale(identifier: "en_US")
        #expect(info("a.pdf", bytes: 812_345).sizeText(locale: locale) == "812 kB")
        #expect(info("a.pdf", bytes: 1_500_000).sizeText(locale: locale) == "1.5 MB")
        #expect(info("a.pdf", bytes: 512).sizeText(locale: locale) == "512 bytes")
    }

    @Test func theNameFallsBackToTheKindsWord() {
        #expect(info("training-plan.pdf").displayName == "training-plan.pdf")
        #expect(info(nil).displayName == "File" && info("").displayName == "File")
    }

    @Test func theGlyphFollowsTheTypeThenTheExtension() {
        #expect(info(nil).symbol == "doc.richtext" && info(nil).type == .pdf)
        #expect(info("x.bin", "application/zip").symbol == "doc.zipper")
        #expect(info("notes.txt", "text/plain").symbol == "doc.text")
        #expect(info("song.mp3", octetStream).symbol == "waveform", "the octet stream says nothing, the extension does")
        #expect(info("deck.key", octetStream).symbol == "rectangle.on.rectangle")
        #expect(info("mystery", octetStream).symbol == "doc" && info("mystery", octetStream).type == nil)
        #expect(info("odd.", octetStream).type == nil)
    }

    @Test func aVideosLengthReadsAsMinutesAndSeconds() {
        #expect(VideoCaption.duration(12) == "0:12")
        #expect(VideoCaption.duration(125) == "2:05")
        #expect(VideoCaption.duration(0) == "0:00")
    }
}
