import Foundation
import Observation

/// The pictures, videos and files picked for the message being composed, owned by `ChatViewModel`: each goes from
/// preparing (the preparer re-encodes, exports or copies it) to uploading (a ticket, then the PUTs, at most
/// `maxConcurrentUploads` at a time) to uploaded, or to failed, where Retry asks for a new ticket. An item the
/// preparer refuses (too large, not something the device can send) is dropped with a popup: there is nothing a retry
/// could change. The entries from the pickers live in `AttachmentComposerModel+Picking.swift`; the send takes
/// `drafts` with it and `reset()` starts over.
@Observable
final class AttachmentComposerModel {
    private(set) var drafts: [AttachmentDraft] = []
    let groupID: String
    /// The room's byte caps (smaller in a conversation): what the preparers refuse against and the popup names.
    let caps: AttachmentCaps
    /// Internal, not private, so the picking extension reaches them.
    let preparer: any MediaPreparer
    let logger: any Logging
    let maxPerMessage: Int
    private let repository: any ChatRepository
    private let uploader: any AttachmentUploader
    private let cache: any AttachmentCache
    private let reporter: GroupErrorReporter
    private let maxConcurrentUploads: Int
    private var tasks: [String: Task<Void, Never>] = [:]
    private var activeUploads = 0
    private var uploadWaiters: [CheckedContinuation<Void, Never>] = []

    init(groupID: String,
         caps: AttachmentCaps,
         repository: any ChatRepository,
         uploader: any AttachmentUploader,
         preparer: any MediaPreparer,
         cache: any AttachmentCache,
         reporter: GroupErrorReporter,
         logger: any Logging,
         maxPerMessage: Int = AppConfig.Chat.Attachments.maxPerMessage,
         maxConcurrentUploads: Int = AppConfig.Chat.Attachments.maxConcurrentUploads) {
        self.groupID = groupID
        self.caps = caps
        self.repository = repository
        self.uploader = uploader
        self.preparer = preparer
        self.cache = cache
        self.reporter = reporter
        self.logger = logger
        self.maxPerMessage = maxPerMessage
        self.maxConcurrentUploads = maxConcurrentUploads
    }

    /// A room left mid-upload: nothing will send these, so the PUTs stop (the tasks hold the model weakly and would
    /// otherwise finish into an orphan object).
    deinit {
        for task in tasks.values { task.cancel() }
    }

    var isEmpty: Bool { drafts.isEmpty }
    var isFull: Bool { drafts.count >= maxPerMessage }
    /// How many more items the message takes; the picker's selection limit.
    var remainingSlots: Int { max(maxPerMessage - drafts.count, 0) }
    /// An item is still preparing or uploading: the message cannot be sent yet.
    var isBusy: Bool { drafts.contains(where: \.isInFlight) }
    /// What the send names.
    var refs: [AttachmentRef] { drafts.compactMap(\.uploadedRef) }

    /// Takes a picked item in: a slot of its kind shows at once (a file's with its name), the preparer and the upload
    /// follow on a task of their own. `nil` when the message is full.
    @discardableResult
    func add(_ source: MediaSource) -> AttachmentDraft? {
        guard !isFull else {
            logger.debug(.chat, "Attachment dropped: the message holds \(maxPerMessage) already")
            return nil
        }
        let draft = AttachmentDraft.preparing(id: UUID().uuidString.lowercased(), kind: source.kind, fileName: source.fileName)
        drafts.append(draft)
        tasks[draft.id] = Task { [weak self] in await self?.prepareAndUpload(draft.id, from: source) }
        return draft
    }

    /// Drops the item, cancelling whatever is running for it, and its files (a slot still preparing has none yet;
    /// `prepareAndUpload` drops what the preparer then delivers).
    func remove(_ draft: AttachmentDraft) {
        let current = drafts.first { $0.id == draft.id } ?? draft
        tasks[draft.id]?.cancel()
        tasks[draft.id] = nil
        drafts.removeAll { $0.id == draft.id }
        deleteFiles(of: current)
    }

    /// A failed upload again, from a new ticket; the prepared files are still on the device.
    func retry(_ draft: AttachmentDraft) {
        guard draft.hasFailed, drafts.contains(where: { $0.id == draft.id }) else { return }
        setState(of: draft.id, to: .uploading(0))
        tasks[draft.id] = Task { [weak self] in await self?.upload(draft.updating(state: .uploading(0))) }
    }

    /// The items went with a message: nothing to show here any more.
    func reset() {
        tasks.values.forEach { $0.cancel() }
        tasks = [:]
        drafts = []
    }

    /// The sent message's files, kept under the ids the backend gave them, so what was just sent never downloads.
    func seedCache(_ sent: [AttachmentDraft], with stored: [Attachment]) {
        for attachment in stored {
            guard let draft = sent.first(where: { $0.uploadedRef?.attachmentId == attachment.id }) else { continue }
            do {
                try cache.store(copying: draft.fileURL, for: attachment.id, variant: .full)
                if let thumbnailURL = draft.thumbnailURL {
                    try cache.store(copying: thumbnailURL, for: attachment.id, variant: .thumbnail)
                }
            } catch {
                logger.warning(.chat, "Attachment \(attachment.id) could not seed the cache: \(error)")
            }
            deleteFiles(of: draft)
        }
    }

    private func prepareAndUpload(_ id: String, from source: MediaSource) async {
        do {
            let prepared = try await prepare(source, id: id)
            guard replace(id, with: prepared.updating(state: .uploading(0))) else {
                deleteFiles(of: prepared)
                return
            }
            await upload(prepared)
        } catch {
            guard !AppError.isCancellation(error) else { return }
            drafts.removeAll { $0.id == id }
            logger.warning(.chat, "Attachment \(id) could not be prepared: \(error)")
            reporter.report(error)
        }
    }

    private func prepare(_ source: MediaSource, id: String) async throws -> AttachmentDraft {
        switch source {
        case .image(let data): try await preparer.prepareImage(data, id: id, caps: caps)
        case .video(let url): try await preparer.prepareVideo(at: url, id: id, caps: caps)
        case .file(let url): try await preparer.prepareFile(at: url, id: id, caps: caps)
        }
    }

    /// A backend refusal for size names no room; the popup should name this room's caps.
    private func inThisRoom(_ error: any Error) -> any Error {
        if case .attachmentTooLarge = error as? AppError { return AppError.attachmentTooLarge(caps: caps) }
        return error
    }

    /// A ticket, then the PUTs, under the concurrency cap; a slot given up while waiting is left alone.
    private func upload(_ draft: AttachmentDraft) async {
        await acquireUploadSlot()
        defer { releaseUploadSlot() }
        guard !Task.isCancelled, drafts.contains(where: { $0.id == draft.id }) else { return }
        do {
            let ticket = try await repository.requestUpload(groupID: groupID, draft.uploadRequest)
            try await uploader.upload(draft, with: ticket) { [weak self] progress in
                self?.setState(of: draft.id, to: .uploading(progress))
            }
            setState(of: draft.id, to: .uploaded(draft.ref(attachmentID: ticket.attachmentId)))
            logger.info(.chat, "Attachment \(draft.id) uploaded as \(ticket.attachmentId) in group \(groupID)")
        } catch {
            guard !AppError.isCancellation(error) else { return }
            setState(of: draft.id, to: .failed)
            logger.error(.chat, "Attachment \(draft.id) upload failed in group \(groupID): \(error)")
            reporter.report(inThisRoom(error))
        }
    }

    private func acquireUploadSlot() async {
        if activeUploads < maxConcurrentUploads {
            activeUploads += 1
            return
        }
        await withCheckedContinuation { uploadWaiters.append($0) }
    }

    /// Hands the slot to the next waiter, who keeps the count, or frees it.
    private func releaseUploadSlot() {
        if uploadWaiters.isEmpty {
            activeUploads -= 1
        } else {
            uploadWaiters.removeFirst().resume()
        }
    }

    /// Replaces the slot of `id`; `false` when it was removed meanwhile.
    private func replace(_ id: String, with draft: AttachmentDraft) -> Bool {
        guard let index = drafts.firstIndex(where: { $0.id == id }) else { return false }
        drafts[index] = draft
        return true
    }

    private func setState(of id: String, to state: AttachmentDraft.State) {
        guard let index = drafts.firstIndex(where: { $0.id == id }) else { return }
        drafts[index].state = state
    }

    private func deleteFiles(of draft: AttachmentDraft) {
        draft.localFiles.forEach { try? FileManager.default.removeItem(at: $0) }
    }
}
