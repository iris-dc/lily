import Foundation

/// One attachment's way through the pipeline, holding the collaborators and the owner weakly so that no suspended
/// prepare, ticket, slot wait or PUT keeps the model alive. The owner is resolved only for the state writes; what
/// answers once it is gone is dropped and its files deleted.
extension AttachmentComposerModel {
    struct AttachmentWork {
        let id: String
        let groupID: String
        let caps: AttachmentCaps
        let preparer: any MediaPreparer
        let repository: any ChatRepository
        let uploader: any AttachmentUploader
        let slots: SlotGate
        let logger: any Logging
        weak var owner: AttachmentComposerModel?

        func prepareAndUpload(from source: MediaSource) async {
            do {
                let prepared = try await prepared(from: source)
                guard owner?.replace(id, with: prepared.updating(state: .uploading(0))) == true else {
                    logger.debug(.chat, "Attachment \(id) prepared for a slot that is gone: files deleted")
                    prepared.deleteLocalFiles()
                    return
                }
                await upload(prepared)
            } catch {
                guard !AppError.isCancellation(error) else { return }
                owner?.dropRefused(id, error)
            }
        }

        /// A ticket, then the PUTs, under the concurrency cap. Cancelled while waiting takes no slot; a slot removed
        /// meanwhile, or an owner gone (whose `deinit` deleted the files), is left alone.
        func upload(_ draft: AttachmentDraft) async {
            do { try await slots.acquire() } catch { return }
            defer { slots.release() }
            guard owner?.holds(draft.id) == true else { return }
            do {
                let ticket = try await repository.requestUpload(groupID: groupID, draft.uploadRequest)
                try await uploader.upload(draft, with: ticket) { [weak owner] share in
                    owner?.setState(of: draft.id, to: .uploading(share))
                }
                guard let owner else {
                    logger.debug(.chat, "Attachment \(draft.id) uploaded for a composer that is gone: files deleted")
                    draft.deleteLocalFiles()
                    return
                }
                owner.finishUpload(draft.id, ref: draft.ref(attachmentID: ticket.attachmentId))
            } catch {
                guard !AppError.isCancellation(error), let owner else { return }
                owner.failUpload(draft.id, error)
            }
        }

        /// The picker's movie copy (`MediaSource.ownedFile`) is removed once the preparer is done with it, whatever the
        /// outcome.
        private func prepared(from source: MediaSource) async throws -> AttachmentDraft {
            defer {
                if let owned = source.ownedFile { try? FileManager.default.removeItem(at: owned) }
            }
            return switch source {
            case .image(let data): try await preparer.prepareImage(data, id: id, caps: caps)
            case .video(let url): try await preparer.prepareVideo(at: url, id: id, caps: caps)
            case .file(let url): try await preparer.prepareFile(at: url, id: id, caps: caps)
            }
        }
    }

    func makeWork(for id: String) -> AttachmentWork {
        AttachmentWork(id: id,
                       groupID: groupID,
                       caps: caps,
                       preparer: preparer,
                       repository: repository,
                       uploader: uploader,
                       slots: slots,
                       logger: logger,
                       owner: self)
    }
}
