import Foundation
import Testing
@testable import lily

/// Pins: who may, what the answer does to the room, the note a catch-up brings after a pin, and deleted messages
/// leaving the bar.
@MainActor
struct ChatViewModelPinTests {
    private let message = ChatMessage.fixture(id: "m1")

    private func makeChat(role: MemberRole? = .admin, group: SportGroup? = nil) async -> (RealtimeHarness, ChatViewModel) {
        let group = group ?? SportGroup.fixture(id: "g", channelEpoch: 1, role: role)
        let harness = RealtimeHarness()
        harness.groups.result = .success([group])
        harness.cache.store(.fixture(groupID: group.id, messages: [.fixture(id: "m1", groupID: group.id)]), for: group.id)
        await harness.connect()
        return (harness, harness.makeChatViewModel(for: group))
    }

    @Test func adminsPinInAGroupAndMembersDoNot() async {
        let (_, admin) = await makeChat(role: .admin)
        let (_, member) = await makeChat(role: .member)
        let (_, conversation) = await makeChat(group: .conversationFixture(id: "c"))

        let unknownRoom = SportGroup.fixture(id: "u", channelEpoch: 1, role: .admin, kind: .unknown("poll_room"))
        let (_, unknownKind) = await makeChat(group: unknownRoom)

        #expect(admin.canPin(message) && !member.canPin(message))
        #expect(conversation.canPin(.fixture(id: "m1", groupID: "c")), "either side of a conversation")
        #expect(!admin.canPin(.fixture(id: "s1", kind: .eventCreated)) && !admin.canPin(message.markingDeleted()))
        #expect(!unknownKind.canPin(.fixture(id: "m1", groupID: "u")), "a room of an unknown kind keeps the backend's rules")
    }

    @Test func aPinTakesTheAnswersPinsAndCatchesUpForTheNote() async {
        let (harness, viewModel) = await makeChat()
        harness.chat.polls.pinLists = [.success(PinList(pins: [.fixture()], channelEpoch: 1))]
        let note = ChatMessage.fixture(id: "m2", kind: .messagePinned, replyTo: .fixture())
        harness.chat.newerPages = [MessagePage(items: [note], hasMore: false, channelEpoch: 1, pins: [.fixture()])]

        await viewModel.pin(message)

        #expect(viewModel.pins == [.fixture()] && viewModel.isPinned("m1"))
        #expect(viewModel.room.messages.last?.kind == .messagePinned)
        #expect(harness.chatLogs(.info).mentioning(["m1", "pinned"]).count == 1)
    }

    @Test func anUnpinTakesTheAnswersPins() async {
        let (harness, viewModel) = await makeChat()
        viewModel.mutateRoom { $0.applyPins([.fixture()]) }
        harness.chat.polls.pinLists = [.success(PinList(pins: [], channelEpoch: 1))]

        await viewModel.unpin("m1")

        #expect(viewModel.pins.isEmpty && harness.chat.polls.unpinned == ["m1"])
        #expect(harness.chatLogs(.info).mentioning(["m1", "unpinned"]).count == 1)
    }

    @Test func aRefusedUnpinReachesThePopupAndKeepsThePins() async {
        let (harness, viewModel) = await makeChat()
        viewModel.mutateRoom { $0.applyPins([.fixture()]) }
        harness.chat.polls.pinLists = [.failure(AppError.insufficientRole)]

        await viewModel.unpin("m1")

        #expect(viewModel.pins == [.fixture()] && harness.errorCenter.current?.error == .insufficientRole)
        #expect(harness.chatLogs(.info).mentioning(["unpinned"]).isEmpty, "nothing was unpinned")
    }

    @Test func theLongPressOffersPinThenUnpinAndNothingToAMember() async {
        let (_, admin) = await makeChat(role: .admin)
        let (_, member) = await makeChat(role: .member)

        #expect(admin.pinning(of: message) == .pin && member.pinning(of: message) == .none)
        admin.mutateRoom { $0.applyPins([.fixture()]) }
        #expect(admin.pinning(of: message) == .unpin)
    }

    @Test func aRefusedPinReachesThePopupAndChangesNothing() async {
        let (harness, viewModel) = await makeChat()
        harness.chat.polls.pinLists = [.failure(AppError.tooManyPins)]

        await viewModel.pin(message)

        #expect(viewModel.pins.isEmpty && harness.errorCenter.current?.error == .tooManyPins)
        #expect(harness.chat.newerRequests.isEmpty, "no catch-up after a refusal")
    }

    @Test func aDeletedMessageLeavesThePins() async {
        let (_, viewModel) = await makeChat()
        viewModel.mutateRoom { $0.applyPins([.fixture(), .fixture(messageId: "m9")]) }

        viewModel.mutateRoom { $0.markDeleted(id: "m9") }

        #expect(viewModel.pins.map(\.messageId) == ["m1"])
    }
}
