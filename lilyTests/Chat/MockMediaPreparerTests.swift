import Foundation
import Testing
@testable import lily

/// The fixtures the mock picker hands over under `-mock-attachment-picker` are in the asset catalog and are what they
/// claim: the camera clip exports through the real video preparer with its hints, the photo and the document are there.
@MainActor
struct MockMediaPreparerTests {
    private let preparer = MockMediaPreparer(logger: SpyLogger())

    @Test func theMockCameraClipIsBundledAndDecodable() async throws {
        let clip = try #require(preparer.videoWithoutPicker())
        defer { try? FileManager.default.removeItem(at: clip) }
        #expect(clip.lastPathComponent == AppConfig.Chat.Attachments.mockVideoFileName)
        let bytes = try Data(contentsOf: clip).count
        #expect(bytes > 0)

        let draft = try await preparer.prepareVideo(at: clip, id: "mock-clip", caps: .group)
        defer { draft.deleteLocalFiles() }

        #expect(draft.kind == .video && draft.durationSeconds == 3 && draft.width == 1280 && draft.height == 720)
        #expect(draft.thumbnailURL != nil)
    }

    @Test func thePhotoAndTheDocumentAreBundled() throws {
        let photo = try #require(preparer.photoWithoutPicker())
        #expect(!photo.isEmpty)

        let document = try #require(preparer.fileWithoutPicker())
        defer { try? FileManager.default.removeItem(at: document) }
        #expect(document.lastPathComponent == AppConfig.Chat.Attachments.mockFileName)
        let bytes = try Data(contentsOf: document).count
        #expect(bytes > 0)
    }
}
