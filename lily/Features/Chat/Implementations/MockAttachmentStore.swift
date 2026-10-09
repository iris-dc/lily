import Foundation
import Synchronization

/// The in-memory stand-in for the bucket behind `-mock-events`: tickets name `mock://attachments/<id>` URLs after the
/// backend's policy (`UploadPolicy`) let the request through, the mock uploader drops the bytes here, a send is refused
/// unless every ref was uploaded by the caller into the same group (the backend's HEAD check), and
/// `MockAttachmentURLProtocol` serves the bytes back to the loader's session. Free of any actor because the protocol
/// reads it from a `URLSession` queue.
nonisolated final class MockAttachmentStore: Sendable {
    private struct Object {
        let groupID: String
        let uploader: String
        let request: UploadRequestPayload
        var data: Data?
        var thumbnail: Data?

        var isUploaded: Bool { data != nil && (request.thumbnail == nil || thumbnail != nil) }
    }

    private struct State {
        var objects: [String: Object] = [:]
        var sequence = 0
    }

    private let state = Mutex(State())

    init() {}

    /// A ticket for `request`, remembered against the caller and the group; refused as the backend would refuse it.
    func issueTicket(groupID: String,
                     _ request: UploadRequestPayload,
                     uploader: String,
                     now: Date,
                     caps: AttachmentCaps) throws -> UploadTicket {
        try UploadPolicy.check(request, caps: caps)
        let id = state.withLock { state in
            state.sequence += 1
            let id = MockChatFixtures.messageID(groupID: AppConfig.Chat.Attachments.mockURLHost, index: state.sequence)
            state.objects[id] = Object(groupID: groupID, uploader: uploader, request: request)
            return id
        }
        let headers = [AppConfig.API.Headers.contentType: request.contentType]
        return UploadTicket(attachmentId: id,
                            upload: UploadTarget(url: url(of: id, variant: .full), headers: headers),
                            thumbnailUpload: request.thumbnail.map { _ in
                                UploadTarget(url: url(of: id, variant: .thumbnail), headers: headers)
                            },
                            expiresAt: now.addingTimeInterval(AppConfig.Chat.Attachments.mockUploadTicketTTL))
    }

    /// The bytes a PUT delivered; a ticket nobody issued is refused like the bucket would.
    func receive(_ data: Data, for id: String, variant: AttachmentVariant) throws {
        try state.withLock { state in
            guard var object = state.objects[id] else { throw AppError.attachmentNotFound }
            switch variant {
            case .full: object.data = data
            case .thumbnail: object.thumbnail = data
            }
            state.objects[id] = object
        }
    }

    /// The attachments a send may store: every ref must name an object the caller uploaded into this group.
    func stored(_ refs: [AttachmentRef], groupID: String, uploader: String, now: Date) throws -> [Attachment] {
        try state.withLock { state in
            try refs.map { ref in
                guard let object = state.objects[ref.attachmentId], object.isUploaded,
                      object.groupID == groupID, object.uploader == uploader else {
                    throw AppError.attachmentNotFound
                }
                return attachment(for: ref, hasThumbnail: object.thumbnail != nil, now: now)
            }
        }
    }

    /// Fresh links for an uploaded object.
    func link(for id: String, now: Date) -> AttachmentLink {
        let hasThumbnail = state.withLock { $0.objects[id]?.thumbnail != nil }
        return AttachmentLink(url: url(of: id, variant: .full),
                              thumbnailUrl: hasThumbnail ? url(of: id, variant: .thumbnail) : nil,
                              urlExpiresAt: now.addingTimeInterval(AppConfig.Chat.Attachments.mockLinkTTL))
    }

    /// The uploaded bytes of `variant`, for the URL protocol and the tests.
    func data(for id: String, variant: AttachmentVariant) -> Data? {
        state.withLock { state in
            switch variant {
            case .full: state.objects[id]?.data
            case .thumbnail: state.objects[id]?.thumbnail
            }
        }
    }

    /// `mock://attachments/<id>` and `mock://attachments/<id>/thumb`, as the protocol parses them back.
    func url(of id: String, variant: AttachmentVariant) -> URL {
        var components = URLComponents()
        components.scheme = AppConfig.Chat.Attachments.mockURLScheme
        components.host = AppConfig.Chat.Attachments.mockURLHost
        components.path = variant == .thumbnail ? "/\(id)/thumb" : "/\(id)"
        return components.url!
    }

    /// The object as the store would serve it, keyed by the mock's URLs.
    private func attachment(for ref: AttachmentRef, hasThumbnail: Bool, now: Date) -> Attachment {
        Attachment(id: ref.attachmentId,
                   kind: ref.kind,
                   contentType: ref.contentType,
                   sizeBytes: ref.sizeBytes,
                   fileName: ref.fileName,
                   width: ref.width,
                   height: ref.height,
                   durationSeconds: ref.durationSeconds,
                   url: url(of: ref.attachmentId, variant: .full),
                   thumbnailUrl: hasThumbnail ? url(of: ref.attachmentId, variant: .thumbnail) : nil,
                   urlExpiresAt: now.addingTimeInterval(AppConfig.Chat.Attachments.mockLinkTTL))
    }
}

/// Answers the mock store's `mock://attachments/...` URLs to a `URLSession`, so `AttachmentLoader` downloads from
/// the mock like from a bucket: 200 with the bytes (and their length, so a download's progress has a total), 404 for
/// anything else.
nonisolated final class MockAttachmentURLProtocol: URLProtocol {
    private static let store = Mutex<MockAttachmentStore?>(nil)

    /// The store the protocol reads; set once by the mock wiring.
    static func serve(_ store: MockAttachmentStore) {
        Self.store.withLock { $0 = store }
    }

    /// A session that resolves the mock URLs and nothing else.
    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockAttachmentURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    override static func canInit(with request: URLRequest) -> Bool {
        request.url?.scheme == AppConfig.Chat.Attachments.mockURLScheme
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url, let client else { return }
        let parts = url.path().split(separator: "/").map(String.init)
        let variant: AttachmentVariant = parts.count > 1 && parts[1] == "thumb" ? .thumbnail : .full
        let data = parts.first.flatMap { id in Self.store.withLock { $0?.data(for: id, variant: variant) } }
        let status = data == nil ? 404 : 200
        let headers = ["Content-Length": String(data?.count ?? 0)]
        let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: headers)!
        client.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client.urlProtocol(self, didLoad: data ?? Data())
        client.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
