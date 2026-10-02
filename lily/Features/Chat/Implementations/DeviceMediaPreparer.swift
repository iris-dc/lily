import Foundation

/// The device's preparers behind the one `MediaPreparer` seam: pictures, videos and files each by their own worker,
/// all writing into the same temporary directory. The remote data layer uses it as it is; the mock one wraps it in
/// `MockMediaPreparer`, which adds the fixtures the pickers would otherwise provide.
final class DeviceMediaPreparer: MediaPreparer {
    private let images: ImagePreparer
    private let videos: VideoPreparer
    private let files: FilePreparer

    convenience init(logger: any Logging) {
        self.init(images: ImagePreparer(logger: logger),
                  videos: VideoPreparer(logger: logger),
                  files: FilePreparer(logger: logger))
    }

    init(images: ImagePreparer, videos: VideoPreparer, files: FilePreparer) {
        self.images = images
        self.videos = videos
        self.files = files
    }

    func prepareImage(_ data: Data, id: String) async throws -> AttachmentDraft {
        try await images.prepareImage(data, id: id)
    }

    func prepareVideo(at url: URL, id: String) async throws -> AttachmentDraft {
        try await videos.prepareVideo(at: url, id: id)
    }

    func prepareFile(at url: URL, id: String) async throws -> AttachmentDraft {
        try await files.prepareFile(at: url, id: id)
    }
}
