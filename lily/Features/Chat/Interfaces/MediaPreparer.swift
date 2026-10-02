import Foundation

/// Turns what a picker handed over into a draft whose files are ready to upload: a picture downsampled to the app's
/// longest side and re-encoded as JPEG (so a HEIC leaves the device as a JPEG) with a thumbnail; a video exported at
/// 720p into an MP4 with a thumbnail frame; any other file copied in under its own name and type.
protocol MediaPreparer {
    /// The picked bytes of an image into a draft keyed by `id` (the draft's client id, chosen before the work starts
    /// so the strip can show the slot meanwhile). A picture over the cap after re-encoding is `.attachmentTooLarge`,
    /// bytes that are no image `.attachmentTypeNotAllowed`.
    func prepareImage(_ data: Data, id: String) async throws -> AttachmentDraft

    /// A video file (the picker's copy, or a recording) into a draft keyed by `id`. Longer than
    /// `videoMaxDurationSeconds` or, once exported, over `videoMaxBytes` is `.attachmentTooLarge`; a file without a
    /// video track `.attachmentTypeNotAllowed`.
    func prepareVideo(at url: URL, id: String) async throws -> AttachmentDraft

    /// Any file into a draft keyed by `id`: copied in (read under its security scope), typed from what the system
    /// knows about it, named after itself. Over `fileMaxBytes` is `.attachmentTooLarge`, a folder `.attachmentTypeNotAllowed`.
    func prepareFile(at url: URL, id: String) async throws -> AttachmentDraft

    /// What "Photo library" hands over without a system picker, or `nil` to open the picker. Only the mock preparer
    /// (`-mock-attachment-picker`) has a photo to offer, because XCUITest cannot drive the out-of-process picker.
    func photoWithoutPicker() -> Data?

    /// What "Camera" hands over without a camera (the mock's recorded clip), or `nil` to open the camera.
    func videoWithoutPicker() -> URL?

    /// What "File" hands over without the files importer (the mock's document), or `nil` to open the importer.
    func fileWithoutPicker() -> URL?
}

extension MediaPreparer {
    func photoWithoutPicker() -> Data? { nil }
    func videoWithoutPicker() -> URL? { nil }
    func fileWithoutPicker() -> URL? { nil }
}
