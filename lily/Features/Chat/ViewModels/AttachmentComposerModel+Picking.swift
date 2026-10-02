import Foundation
import PhotosUI
import SwiftUI
import UIKit

/// How things get into the composer: the Photos picker (pictures and videos, told apart by what the item can give),
/// the camera, the files importer and, under `-mock-attachment-picker`, the bundled fixtures without any picker. Each
/// entry opens a slot of its kind through `add(_:)`; the preparer and the upload follow.
extension AttachmentComposerModel {
    /// Whether the pickers are stood in for by the bundled fixtures (`-mock-attachment-picker`): "Photo library" adds
    /// the photo, "Camera" the clip and "File" the document at once instead of opening anything.
    var picksWithoutPicker: Bool { preparer.photoWithoutPicker() != nil }

    /// Items from the Photos picker, loaded one by one; one that will not load is skipped with a warning.
    func add(pickerItems: [PhotosPickerItem]) async {
        for item in pickerItems.prefix(remainingSlots) {
            if item.isVideo {
                await addVideo(from: item)
            } else {
                await addPhoto(from: item)
            }
        }
    }

    func add(cameraImage: UIImage) {
        guard let data = cameraImage.jpegData(compressionQuality: 1) else { return }
        add(imageData: data)
    }

    @discardableResult
    func add(imageData: Data) -> AttachmentDraft? {
        add(.image(imageData))
    }

    @discardableResult
    func add(videoAt url: URL) -> AttachmentDraft? {
        add(.video(url))
    }

    @discardableResult
    func add(fileAt url: URL) -> AttachmentDraft? {
        add(.file(url))
    }

    /// The files importer's pick, as many as the message still takes.
    func add(fileURLs: [URL]) {
        for url in fileURLs.prefix(remainingSlots) {
            add(fileAt: url)
        }
    }

    func addPhotoWithoutPicker() {
        guard let data = preparer.photoWithoutPicker() else { return }
        add(imageData: data)
    }

    func addVideoWithoutPicker() {
        guard let url = preparer.videoWithoutPicker() else { return }
        add(videoAt: url)
    }

    func addFileWithoutPicker() {
        guard let url = preparer.fileWithoutPicker() else { return }
        add(fileAt: url)
    }

    /// The files importer failed before it named a file; nothing is shown, the log says why.
    func noteFileImportFailure(_ error: any Error) {
        logger.warning(.chat, "The files importer failed: \(error.localizedDescription)")
    }

    private func addPhoto(from item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            logger.warning(.chat, "A picked photo could not be loaded")
            return
        }
        add(imageData: data)
    }

    private func addVideo(from item: PhotosPickerItem) async {
        guard let movie = try? await item.loadTransferable(type: PickedMovie.self) else {
            logger.warning(.chat, "A picked video could not be loaded")
            return
        }
        add(videoAt: movie.url)
    }
}

private extension PhotosPickerItem {
    var isVideo: Bool {
        supportedContentTypes.contains { $0.conforms(to: .movie) }
    }
}
