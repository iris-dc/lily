import Foundation
import Observation

/// The pictures, videos and files picked for the message being composed: each goes from preparing (re-encoded,
/// exported or copied by the preparer) to uploading (a ticket, then the PUTs, at most `maxConcurrentUploads` at a time)
/// to uploaded, or to failed, where Retry asks for a new ticket. An item the preparer refuses (too large, not something
/// the device can send) is dropped with a popup, since nothing a retry could change; the send takes `drafts` with it and
/// `reset()` starts over.
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
    let repository: any ChatRepository
    let uploader: any AttachmentUploader
    let slots: SlotGate
    private(set) var tasks: [String: Task<Void, Never>] = [:]
    private let cache: any AttachmentCache
    private let reporter: GroupErrorReporter
    /// Stored ids whose files went (or are going) into the cache: the answer and the live echo both settle one
    /// message, and the second must neither copy again nor delete what the first is still copying.
    private var seeded: Set<String> = []

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
        slots = SlotGate(limit: maxConcurrentUploads)
    }

    /// A room left with items in the strip: nothing will send them, so the PUTs stop and the files go. The pipeline
    /// holds this model weakly, so this runs while work is in flight; `reset()` empties `drafts` before a send, so a
    /// sent message's files are never deleted here.
    deinit {
        for task in tasks.values { task.cancel() }
        for draft in drafts { draft.deleteLocalFiles() }
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
    /// follow on a task of their own, which holds this model weakly. `nil` when the message is full.
    @discardableResult
    func add(_ source: MediaSource) -> AttachmentDraft? {
        guard !isFull else {
            logger.debug(.chat, "Attachment dropped: the message holds \(maxPerMessage) already")
            return nil
        }
        let draft = AttachmentDraft.preparing(id: UUID().uuidString.lowercased(), kind: source.kind, fileName: source.fileName)
        drafts.append(draft)
        tasks[draft.id] = Task { [work = makeWork(for: draft.id)] in await work.prepareAndUpload(from: source) }
        return draft
    }

    /// Drops the item, cancelling whatever is running for it, and its files (a slot still preparing has none yet; the
    /// pipeline deletes what the preparer then delivers).
    func remove(_ draft: AttachmentDraft) {
        let current = drafts.first { $0.id == draft.id } ?? draft
        tasks[draft.id]?.cancel()
        tasks[draft.id] = nil
        drafts.removeAll { $0.id == draft.id }
        current.deleteLocalFiles()
    }

    /// A failed upload again, from a new ticket; the prepared files are still on the device.
    func retry(_ draft: AttachmentDraft) {
        guard draft.hasFailed, holds(draft.id) else { return }
        setState(of: draft.id, to: .uploading(0))
        tasks[draft.id] = Task { [work = makeWork(for: draft.id)] in await work.upload(draft.updating(state: .uploading(0))) }
    }

    /// The items went with a message: nothing to show here any more.
    func reset() {
        tasks.values.forEach { $0.cancel() }
        tasks = [:]
        drafts = []
    }

    /// The sent message's files, kept under the ids the backend gave them, so what was just sent never downloads.
    /// Each id is claimed before the first await, so a second settle of the same message is a no-op.
    func seedCache(_ sent: [AttachmentDraft], with stored: [Attachment]) async {
        for attachment in stored {
            guard let draft = sent.first(where: { $0.uploadedRef?.attachmentId == attachment.id }),
                  seeded.insert(attachment.id).inserted else { continue }
            do {
                try await cache.store(copying: draft.fileURL, for: attachment.id, variant: .full)
                if let thumbnailURL = draft.thumbnailURL {
                    try await cache.store(copying: thumbnailURL, for: attachment.id, variant: .thumbnail)
                }
            } catch {
                logger.warning(.chat, "Attachment \(attachment.id) could not seed the cache: \(error)")
            }
            draft.deleteLocalFiles()
        }
    }

    // MARK: The pipeline's state writes

    /// Whether the slot of `id` is still in the strip.
    func holds(_ id: String) -> Bool {
        drafts.contains { $0.id == id }
    }

    /// Replaces the slot of `id` with the preparer's answer; `false` when it was removed meanwhile.
    func replace(_ id: String, with draft: AttachmentDraft) -> Bool {
        guard let index = drafts.firstIndex(where: { $0.id == id }) else { return false }
        drafts[index] = draft
        return true
    }

    func setState(of id: String, to state: AttachmentDraft.State) {
        guard let index = drafts.firstIndex(where: { $0.id == id }) else { return }
        drafts[index].state = state
    }

    /// The preparer's verdict on the slot of `id` (too large, not something the device can send): the slot goes with
    /// a popup, since nothing a retry could change.
    func dropRefused(_ id: String, _ error: any Error) {
        drafts.removeAll { $0.id == id }
        logger.warning(.chat, "Attachment \(id) could not be prepared: \(error)")
        reporter.report(error)
    }

    /// Both objects are in the bucket under the ticket's id: the send may name `ref`.
    func finishUpload(_ id: String, ref: AttachmentRef) {
        setState(of: id, to: .uploaded(ref))
        logger.info(.chat, "Attachment \(id) uploaded as \(ref.attachmentId) in group \(groupID)")
    }

    /// The ticket or a PUT failed: the slot offers Retry, and a size refusal's popup names this room's caps.
    func failUpload(_ id: String, _ error: any Error) {
        setState(of: id, to: .failed)
        logger.error(.chat, "Attachment \(id) upload failed in group \(groupID): \(error)")
        reporter.report(inThisRoom(error))
    }

    /// A backend refusal for size names no room; the popup should name this room's caps.
    private func inThisRoom(_ error: any Error) -> any Error {
        if case .attachmentTooLarge = error as? AppError { return AppError.attachmentTooLarge(caps: caps) }
        return error
    }
}
