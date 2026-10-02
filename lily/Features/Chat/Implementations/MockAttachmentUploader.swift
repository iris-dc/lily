import Foundation

/// Uploads into the mock store: the progress ring moves in `mockUploadSteps` steps over `mockUploadDelay` (paced by
/// an injected `Sleep`, so the tests need no clock), then the file's bytes land under the ticket's id.
final class MockAttachmentUploader: AttachmentUploader {
    private let store: MockAttachmentStore
    private let sleep: Sleep

    init(store: MockAttachmentStore, sleep: @escaping Sleep = systemSleep) {
        self.store = store
        self.sleep = sleep
    }

    func upload(_ draft: AttachmentDraft,
                with ticket: UploadTicket,
                progress: @escaping @MainActor (Double) -> Void) async throws {
        let data = try Data(contentsOf: draft.fileURL)
        let steps = AppConfig.Chat.Attachments.mockUploadSteps
        for step in 1...steps {
            try await sleep(AppConfig.Chat.Attachments.mockUploadDelay / steps)
            progress(Double(step) / Double(steps))
        }
        try store.receive(data, for: ticket.attachmentId, variant: .full)
        if ticket.thumbnailUpload != nil, let thumbnailURL = draft.thumbnailURL {
            try store.receive(try Data(contentsOf: thumbnailURL), for: ticket.attachmentId, variant: .thumbnail)
        }
    }
}
