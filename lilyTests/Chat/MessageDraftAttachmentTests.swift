import Foundation
import Testing
@testable import lily

/// A draft with pictures: sendable with words or with at least one uploaded picture, never while one is still on its
/// way or failed; the pending message carries the drafts and rebuilds the same draft for a retry.
struct MessageDraftAttachmentTests {
    @Test func anUploadedPictureAloneMakesTheDraftValid() {
        var draft = MessageDraft(clientMessageID: "c-1")
        draft.attachments = [.fixture(state: .uploaded(.fixture(attachmentID: "att-1")))]

        #expect(draft.isValid && draft.issues.isEmpty)
        #expect(draft.uploadedRefs.map(\.attachmentId) == ["att-1"])
        let expected = SendMessagePayload(clientMessageId: "c-1", text: nil, attachments: [.fixture(attachmentID: "att-1")])
        #expect(draft.payload == expected)
    }

    @Test func aPictureStillOnItsWayHoldsTheSendEvenWithWords() {
        var draft = MessageDraft(clientMessageID: "c-1")
        draft.text = "Look"
        for state in [AttachmentDraft.State.preparing, .uploading(0.4), .failed] {
            draft.attachments = [.fixture(state: state)]
            #expect(draft.issues == [.attachmentsPending] && !draft.isValid, "\(state)")
        }

        draft.attachments = [.fixture(state: .uploaded(.fixture())), .fixture(id: "d2", state: .uploading(0.9))]
        #expect(draft.issues == [.attachmentsPending])
        #expect(draft.payload.attachments?.count == 1, "the payload names the uploaded ones only")
    }

    @Test func noWordsAndNoPicturesIsEmpty() {
        var draft = MessageDraft(clientMessageID: "c-1")
        #expect(draft.issues == [.empty])

        draft.attachments = [.fixture(state: .uploading(0.1))]
        #expect(draft.issues == [.empty, .attachmentsPending], "nothing uploaded yet counts as empty too")
    }

    @Test func aPendingMessageCarriesTheDraftsAndRebuildsThem() {
        var draft = MessageDraft(clientMessageID: "c-1")
        draft.text = " Look "
        draft.attachments = [.fixture()]
        let pending = PendingMessage(draft: draft, sentAt: .now)

        #expect(pending.hasAttachments && pending.attachments == draft.attachments && pending.text == "Look")
        #expect(pending.draft.attachments == draft.attachments && pending.draft.payload == draft.payload)
        #expect(pending.droppingReply().attachments == draft.attachments)
    }

    @Test func draftStatesAnswerTheirQuestions() {
        let uploading = AttachmentDraft.fixture(state: .uploading(0.25))
        #expect(uploading.isInFlight && !uploading.hasFailed && uploading.progress == 0.25 && uploading.uploadedRef == nil)
        let uploaded = AttachmentDraft.fixture(state: .uploaded(.fixture()))
        #expect(!uploaded.isInFlight && uploaded.progress == 1 && uploaded.uploadedRef == .fixture())
        let failed = AttachmentDraft.fixture(state: .failed)
        #expect(failed.hasFailed && failed.progress == nil && !failed.isInFlight)
        #expect(AttachmentDraft.fixture(state: .preparing).isInFlight)
        #expect(uploaded.previewURL == uploaded.thumbnailURL && uploaded.localFiles.count == 2)
        #expect(uploaded.aspectRatio.isAbout(4.0 / 3.0))
    }

    /// The ref a draft names once uploaded carries the device's hints and whether a thumbnail went up.
    @Test func theRefTakesTheTicketIdAndTheHints() {
        let draft = AttachmentDraft.fixture()
        let ref = draft.ref(attachmentID: "01K6B")
        #expect(ref == AttachmentRef(attachmentId: "01K6B",
                                     kind: .image,
                                     contentType: "image/jpeg",
                                     sizeBytes: 812_345,
                                     width: 2048,
                                     height: 1536,
                                     hasThumbnail: true))

        let plain = AttachmentDraft(clientAttachmentID: "d",
                                    kind: .image,
                                    fileURL: draft.fileURL,
                                    contentType: "image/jpeg",
                                    sizeBytes: 1)
        #expect(!plain.ref(attachmentID: "x").hasThumbnail && plain.previewURL == plain.fileURL && plain.localFiles.count == 1)
    }

    /// A file name over the backend's cap is cut on the device (UTF-16 units, never splitting a character).
    @Test func aLongFileNameIsCutToTheCap() {
        let limit = AppConfig.Chat.Attachments.fileNameMaxLength
        let long = String(repeating: "a", count: limit - 1) + "😀😀"
        let draft = AttachmentDraft(clientAttachmentID: "d",
                                    kind: .file,
                                    fileURL: URL(fileURLWithPath: "/tmp/x"),
                                    contentType: "application/pdf",
                                    sizeBytes: 1,
                                    fileName: long)

        #expect(draft.fileName == String(repeating: "a", count: limit - 1))
        #expect(draft.uploadRequest.fileName == draft.fileName && draft.ref(attachmentID: "x").fileName == draft.fileName)
    }

    @Test func thePreparingSlotIsKeyedByItsId() {
        let slot = AttachmentDraft.preparing(id: "slot-1", kind: .image)
        #expect(slot.id == "slot-1" && slot.state == .preparing && slot.sizeBytes == 0 && slot.thumbnailURL == nil)
        #expect(slot.fileURL.lastPathComponent == "slot-1")
    }
}
