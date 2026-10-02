import Foundation
import Testing
@testable import lily

/// The pictures of a message on their way: preparing, uploading under the concurrency cap, uploaded; removal, the cap,
/// a failed upload and its retry, a refused picture, and the cache seeded with what was sent.
@MainActor
struct AttachmentComposerModelTests {
    private let harness = RealtimeHarness()
    private let group = SportGroup.fixture(id: "g", role: .member)
    private let photo = Data(repeating: 7, count: 1000)

    private func makeModel(maxPerMessage: Int = AppConfig.Chat.Attachments.maxPerMessage) -> AttachmentComposerModel {
        harness.makeAttachmentComposer(for: group, maxPerMessage: maxPerMessage)
    }

    @Test func aPictureIsPreparedUploadedAndNamed() async throws {
        let model = makeModel()

        let slot = try #require(model.add(imageData: photo))
        #expect(model.drafts.map(\.state) == [.preparing] && model.isBusy && model.refs.isEmpty)
        await settle(until: { !model.isBusy })

        let draft = try #require(model.drafts.first)
        #expect(draft.id == slot.id && draft.uploadedRef?.attachmentId == "att-1" && draft.sizeBytes == 1000)
        #expect(model.refs.map(\.attachmentId) == ["att-1"] && !model.isEmpty)
        #expect(harness.chat.uploadRequests.map(\.groupID) == ["g"])
        let request = harness.chat.uploadRequests[0].request
        #expect(request.sizeBytes == 1000 && request.thumbnail != nil && request.clientAttachmentId == slot.id)
        #expect(harness.uploader.uploads.map(\.ticket.attachmentId) == ["att-1"])
        #expect(harness.chatLogs(.info).contains("Attachment \(slot.id) uploaded as att-1 in group g"))
    }

    @Test func theStatesFollowThePipeline() async throws {
        let model = makeModel()
        harness.preparer.holdsRequests = true
        harness.uploader.holdsRequests = true

        let slot = try #require(model.add(imageData: photo))
        await settle(until: { harness.preparer.preparedIDs == [slot.id] })
        #expect(model.drafts[0].state == .preparing)

        harness.preparer.releaseRequests()
        await settle(until: { harness.uploader.inFlight == 1 })
        #expect(model.drafts[0].state == .uploading(0.5), "the uploader reported half-way before the hold")

        harness.uploader.releaseRequests()
        await settle(until: { !model.isBusy })
        #expect(model.drafts[0].uploadedRef != nil)
    }

    @Test func removeCancelsTheUploadAndDropsTheSlot() async throws {
        let model = makeModel()
        harness.uploader.holdsRequests = true
        let slot = try #require(model.add(imageData: photo))
        await settle(until: { harness.uploader.inFlight == 1 })

        model.remove(model.drafts[0])
        harness.uploader.releaseRequests()
        await harness.yield()

        #expect(model.isEmpty && !model.isBusy && harness.errorCenter.current == nil)
        #expect(!harness.chatLogs(.info).contains { $0.hasPrefix("Attachment \(slot.id) uploaded") })
    }

    /// The prepared files go with the slot, whether the upload was running or the preparer had not answered yet (its
    /// late answer is dropped too), so nothing of a removed item stays in the temporary directory.
    @Test func removeDeletesTheDraftsFilesWhateverItsState() async throws {
        let model = makeModel()
        harness.uploader.holdsRequests = true
        model.add(imageData: photo)
        await settle(until: { harness.uploader.inFlight == 1 })
        let uploading = try #require(model.drafts.first)
        #expect(uploading.localFiles.allSatisfy { FileManager.default.fileExists(atPath: $0.path()) })

        model.remove(uploading)
        harness.uploader.releaseRequests()

        #expect(uploading.localFiles.allSatisfy { !FileManager.default.fileExists(atPath: $0.path()) })

        harness.preparer.holdsRequests = true
        let preparing = try #require(model.add(imageData: photo))
        await settle(until: { harness.preparer.preparedIDs.contains(preparing.id) })
        model.remove(preparing)
        harness.preparer.releaseRequests()
        await harness.yield()

        let prepared = FileManager.default.temporaryDirectory.appending(path: "\(preparing.id).jpg")
        await settle(until: { !FileManager.default.fileExists(atPath: prepared.path()) })
        #expect(model.isEmpty && harness.chat.uploadRequests.count == 1, "the late answer never asked for a ticket")
    }

    @Test func theCapRefusesMorePictures() async {
        let model = makeModel(maxPerMessage: 2)

        #expect(model.add(imageData: photo) != nil && model.add(imageData: photo) != nil)
        #expect(model.isFull && model.remainingSlots == 0)
        #expect(model.add(imageData: photo) == nil && model.drafts.count == 2)
        #expect(harness.chatLogs(.debug).contains("Attachment dropped: the message holds 2 already"))
        await settle(until: { !model.isBusy })
    }

    @Test func aFailedUploadIsMarkedReportedAndRetried() async throws {
        let model = makeModel()
        harness.uploader.errors = [AppError.attachmentUploadFailed]

        model.add(imageData: photo)
        await settle(until: { !model.isBusy })

        #expect(model.drafts.map(\.hasFailed) == [true] && model.refs.isEmpty)
        #expect(harness.errorCenter.current?.error == .attachmentUploadFailed)
        #expect(harness.chatLogs(.error).contains { $0.hasPrefix("Attachment \(model.drafts[0].id) upload failed in group g") })

        model.retry(model.drafts[0])
        await settle(until: { !model.isBusy })

        #expect(model.drafts[0].uploadedRef?.attachmentId == "att-2", "the retry asks for a new ticket")
        #expect(harness.chat.uploadRequests.count == 2 && harness.uploader.uploads.count == 2)
    }

    /// A picture the preparer refuses is a verdict: the slot goes and the popup says why.
    @Test func aRefusedPictureIsDroppedWithThePopup() async throws {
        let model = makeModel()
        harness.preparer.error = AppError.attachmentTooLarge

        let slot = try #require(model.add(imageData: photo))
        await settle(until: { model.isEmpty })

        #expect(harness.errorCenter.current?.error == .attachmentTooLarge && harness.chat.uploadRequests.isEmpty)
        #expect(harness.chatLogs(.warning).contains("Attachment \(slot.id) could not be prepared: attachmentTooLarge"))
    }

    @Test func atMostTwoUploadsRunAtOnce() async {
        let model = makeModel()
        harness.uploader.holdsRequests = true

        for _ in 0..<3 { model.add(imageData: photo) }
        await settle(until: { harness.uploader.inFlight == 2 })
        await harness.yield()
        #expect(harness.uploader.uploads.count == 2, "the third waits for a slot")

        harness.uploader.releaseRequests()
        await settle(until: { !model.isBusy })
        #expect(harness.uploader.uploads.count == 3 && model.refs.count == 3)
    }

    @Test func seedCacheKeepsTheSentFilesUnderTheStoredIds() async throws {
        let model = makeModel()
        model.add(imageData: photo)
        await settle(until: { !model.isBusy })
        let sent = model.drafts
        let stored = lily.Attachment.fixture(id: "att-1")

        model.seedCache(sent, with: [stored, .fixture(id: "someone-elses")])

        let thumbnail = try #require(sent[0].thumbnailURL)
        #expect(harness.attachmentCache.copied == [
            FakeAttachmentCache.Copy(id: "att-1", variant: .full, source: sent[0].fileURL),
            FakeAttachmentCache.Copy(id: "att-1", variant: .thumbnail, source: thumbnail),
        ])
        #expect(harness.attachmentCache.fileURL(for: "att-1", variant: .full) != nil)
    }

    @Test func resetAndThePickerStandInFollowTheConfiguration() async {
        let model = makeModel()
        #expect(!model.picksWithoutPicker)
        harness.preparer.photo = photo
        #expect(model.picksWithoutPicker)

        model.addPhotoWithoutPicker()
        #expect(model.drafts.count == 1)
        await settle(until: { !model.isBusy })

        model.reset()
        #expect(model.isEmpty && !model.isBusy && model.refs.isEmpty)
    }
}
