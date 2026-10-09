import Foundation
import Testing
@testable import lily

/// The composer with videos and files: each entry opens a slot of its kind and routes to its preparer, a file's slot
/// already shows its name, the importer's pick is cut to the free slots, and the mock fixtures stand in for the
/// pickers.
@MainActor
struct AttachmentComposerModelKindTests {
    private let harness = RealtimeHarness()
    private let group = SportGroup.fixture(id: "g", role: .member)
    private let clip = URL(fileURLWithPath: "/tmp/picked-clip.mov")
    private let document = URL(fileURLWithPath: "/tmp/Documents/training-plan.pdf")

    private func makeModel(maxPerMessage: Int = AppConfig.Chat.Attachments.maxPerMessage) -> AttachmentComposerModel {
        harness.makeAttachmentComposer(for: group, maxPerMessage: maxPerMessage)
    }

    @Test func aVideoGoesToTheVideoPreparerAndIsNamedAsOne() async throws {
        let model = makeModel()

        let slot = try #require(model.add(videoAt: clip))
        #expect(slot.kind == .video && slot.fileName == nil && model.drafts.map(\.state) == [.preparing])
        await settle(until: { !model.isBusy })

        #expect(harness.preparer.preparedVideoURLs == [clip] && harness.preparer.preparedFileURLs.isEmpty)
        let draft = try #require(model.drafts.first)
        #expect(draft.kind == .video && draft.durationSeconds == 12 && draft.uploadedRef?.attachmentId == "att-1")
        let request = try #require(harness.chat.uploadRequests.first?.request)
        #expect(request.kind == .video && request.contentType == "video/mp4" && request.thumbnail != nil)
        #expect(request.durationSeconds == 12)
        #expect(model.refs.map(\.kind) == [.video])
    }

    @Test func aFileGoesToTheFilePreparerWithItsNameOnTheSlot() async throws {
        let model = makeModel()
        harness.preparer.holdsRequests = true

        let slot = try #require(model.add(fileAt: document))
        #expect(slot.kind == .file && slot.fileName == "training-plan.pdf", "the chip shows the name before the copy is done")
        await settle(until: { harness.preparer.preparedFileURLs == [document] })
        harness.preparer.releaseRequests()
        await settle(until: { !model.isBusy })

        let draft = try #require(model.drafts.first)
        #expect(draft.kind == .file && draft.contentType == "application/pdf" && draft.thumbnailURL == nil)
        let request = try #require(harness.chat.uploadRequests.first?.request)
        #expect(request.kind == .file && request.fileName == "training-plan.pdf" && request.thumbnail == nil)
        #expect(harness.uploader.uploads.first?.ticket.thumbnailUpload == nil, "a file's ticket names no thumbnail target")
    }

    @Test func theImportersPickIsCutToTheFreeSlots() async {
        let model = makeModel(maxPerMessage: 2)
        let urls = (1...3).map { URL(fileURLWithPath: "/tmp/file-\($0).txt") }

        model.add(fileURLs: urls)

        #expect(model.drafts.map(\.fileName) == ["file-1.txt", "file-2.txt"] && model.isFull)
        await settle(until: { !model.isBusy })
        #expect(harness.preparer.preparedFileURLs == Array(urls.prefix(2)))
    }

    @Test func theMockFixturesStandInForEveryPicker() async {
        let model = makeModel()
        harness.preparer.photo = Data(repeating: 1, count: 10)
        harness.preparer.video = clip
        harness.preparer.file = document

        model.addPhotoWithoutPicker()
        model.addVideoWithoutPicker()
        model.addFileWithoutPicker()
        await settle(until: { !model.isBusy })

        #expect(model.drafts.map(\.kind) == [.image, .video, .file] && model.refs.count == 3)
        #expect(harness.preparer.preparedVideoURLs == [clip] && harness.preparer.preparedFileURLs == [document])
    }

    @Test func withoutFixturesTheStandInsAddNothing() async {
        let model = makeModel()

        model.addVideoWithoutPicker()
        model.addFileWithoutPicker()
        model.noteFileImportFailure(URLError(.cannotOpenFile))

        #expect(model.isEmpty && !model.picksWithoutPicker)
        #expect(harness.chatLogs(.warning).contains { $0.hasPrefix("The files importer failed") })
    }

    /// A conversation's composer hands the preparers the smaller caps, a group's the full ones, so a 6 MB file is
    /// refused on the device in a conversation and taken in a group; a backend refusal for size is restated with the
    /// room's caps before it reaches the popup, since the code names no room.
    @Test func aConversationPreparesAgainstTheDirectCapsAndNamesThemInThePopup() async throws {
        let conversation = harness.makeAttachmentComposer(for: .fixture(id: "dm", role: .member, kind: .direct))
        let group = makeModel()

        _ = try #require(conversation.add(fileAt: document))
        _ = try #require(group.add(videoAt: clip))
        await settle(until: { !conversation.isBusy && !group.isBusy })
        #expect(harness.preparer.preparedCaps == [.direct, .group])

        harness.chat.uploadError = AppError.attachmentTooLarge(caps: .group)
        _ = try #require(conversation.add(fileAt: document))
        await settle(until: { conversation.drafts.contains { $0.state == AttachmentDraft.State.failed } })
        #expect(harness.errorCenter.current?.error == .attachmentTooLarge(caps: .direct))
    }

    /// A refused video or file is a verdict like a refused picture: the slot goes and the popup says why.
    @Test func aRefusedVideoIsDroppedWithThePopup() async throws {
        let model = makeModel()
        harness.preparer.error = AppError.attachmentTooLarge(caps: .group)

        let slot = try #require(model.add(videoAt: clip))
        await settle(until: { model.isEmpty })

        #expect(harness.errorCenter.current?.error == .attachmentTooLarge(caps: .group) && harness.chat.uploadRequests.isEmpty)
        let warning = "Attachment \(slot.id) could not be prepared: attachmentTooLarge"
        #expect(harness.chatLogs(.warning).contains { $0.hasPrefix(warning) })
    }
}
