import Foundation
import UIKit

/// The preparer of a run without system pickers (`-mock-attachment-picker`): prepares like the real one, so the strip
/// and the bubble render real thumbnails and a real export, and hands the bundled fixtures over as what the pickers
/// would have given, because XCUITest cannot drive the out-of-process picker, the camera or the files importer:
/// `MockAttachmentPhoto` for "Photo library", `MockAttachmentVideo` for "Camera" (a recorded clip) and
/// `MockAttachmentFile` for "File". The data sets live in `Assets.xcassets`, so `lily/` stays Swift and assets only.
final class MockMediaPreparer: MediaPreparer {
    private let real: DeviceMediaPreparer
    private let logger: any Logging

    private typealias Config = AppConfig.Chat.Attachments

    init(logger: any Logging) {
        real = DeviceMediaPreparer(logger: logger)
        self.logger = logger
    }

    func prepareImage(_ data: Data, id: String) async throws -> AttachmentDraft {
        try await real.prepareImage(data, id: id)
    }

    func prepareVideo(at url: URL, id: String) async throws -> AttachmentDraft {
        try await real.prepareVideo(at: url, id: id)
    }

    func prepareFile(at url: URL, id: String) async throws -> AttachmentDraft {
        try await real.prepareFile(at: url, id: id)
    }

    func photoWithoutPicker() -> Data? {
        guard let data = asset(named: Config.mockPhotoAssetName) else { return nil }
        logger.debug(.chat, "Mock picker handed over the bundled photo")
        return data
    }

    func videoWithoutPicker() -> URL? {
        fixtureFile(asset: Config.mockVideoAssetName, named: Config.mockVideoFileName)
    }

    func fileWithoutPicker() -> URL? {
        fixtureFile(asset: Config.mockFileAssetName, named: Config.mockFileName)
    }

    /// The data set written to the temporary directory under `name`, as a picker would hand a file over.
    private func fixtureFile(asset: String, named name: String) -> URL? {
        guard let data = self.asset(named: asset) else { return nil }
        let url = FileManager.default.temporaryDirectory.appending(path: name)
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            logger.error(.chat, "Mock attachment fixture \(asset) could not be written: \(error)")
            return nil
        }
        logger.debug(.chat, "Mock picker handed over the bundled \(asset)")
        return url
    }

    private func asset(named name: String) -> Data? {
        guard let asset = NSDataAsset(name: name) else {
            logger.error(.chat, "Mock attachment \(name) missing from the asset catalog")
            return nil
        }
        return asset.data
    }
}
