import Foundation
import Testing
@testable import lily

/// The game behind a system row, copying, and who may delete.
@MainActor
struct ChatViewModelEventsTests {
    private let group = SportGroup.fixture(id: "g", channelEpoch: 1, role: .member)
    private let systemRow = ChatMessage.fixture(id: "s1", senderName: "Marta", kind: .eventCreated, text: nil, eventID: "e")
    private let game = SportEvent.fixture(id: "e", title: "Sunday 5-a-side")

    private func makeChat(role: MemberRole = .member) async -> (RealtimeHarness, ChatViewModel) {
        let harness = RealtimeHarness()
        let group = SportGroup.fixture(id: "g", channelEpoch: 1, role: role)
        harness.groups.result = .success([group])
        harness.cache.store(.fixture(messages: [.fixture(id: "m1")]), for: "g")
        await harness.connect()
        return (harness, harness.makeChatViewModel(for: group))
    }

    @Test func aSystemRowNamesTheGameOnceItIsLoadedAndFetchesItOnce() async {
        let (harness, viewModel) = await makeChat()
        harness.events.result = .success([game])
        #expect(viewModel.systemText(for: systemRow) == "Marta created a game")

        await viewModel.loadLinkedContent(for: systemRow)
        await viewModel.loadLinkedContent(for: systemRow)
        #expect(viewModel.systemText(for: systemRow) == "Marta created Sunday 5-a-side")
        #expect(harness.events.fetchedEventIDs == ["e"])
        #expect(await viewModel.destination(for: systemRow) == .event(game))
        #expect(harness.events.fetchedEventIDs == ["e"], "the tap reuses the loaded game")
    }

    @Test func aGoneGameKeepsTheFallbackQuietlyAndReportsOnlyWhenOpened() async {
        let (harness, viewModel) = await makeChat()

        await viewModel.loadLinkedContent(for: systemRow)
        #expect(viewModel.systemText(for: systemRow) == "Marta created a game")
        #expect(harness.errorCenter.current == nil)
        #expect(harness.logger.messages(in: .chat, at: .warning).contains { $0.hasPrefix("Event e behind a system row") })

        #expect(await viewModel.destination(for: systemRow) == nil)
        #expect(harness.errorCenter.current?.error == .eventNotFound)
        #expect(await viewModel.destination(for: .fixture(id: "t", text: "plain")) == nil, "a text row has no game")
    }

    @Test func aLiveEventCreatedRowBumpsTheEventChanges() async {
        let (harness, viewModel) = await makeChat()
        await viewModel.appear()
        let before = harness.eventChanges.version

        harness.transport.post(.message(.fixture(id: "m2")), to: .room(groupID: "g", epoch: 1))
        await settle(until: { viewModel.room.messages.count == 2 })
        await harness.yield()
        #expect(harness.eventChanges.version == before, "a text message changes no game")

        harness.transport.post(.message(systemRow), to: .room(groupID: "g", epoch: 1))
        await settle(until: { harness.eventChanges.version == before + 1 })
        await viewModel.cancel()
    }

    @Test func copyPutsTheTextOnThePasteboardAndSkipsRowsWithout() async {
        let (harness, viewModel) = await makeChat()

        viewModel.copy(.fixture(id: "m1", text: "Thursday works."))
        viewModel.copy(.fixture(id: "m2", text: nil, isDeleted: true))

        #expect(harness.pasteboard.copied == ["Thursday works."])
    }

    @Test func theSenderAndAdminsMayDeleteLiveTextRowsOnly() async {
        let (_, member) = await makeChat()
        let own = ChatMessage.fixture(id: "m1", senderUserID: TestFixtures.user.id)
        let other = ChatMessage.fixture(id: "m2")
        #expect(member.canDelete(own) && !member.canDelete(other))
        #expect(!member.canDelete(.fixture(id: "m3", senderUserID: TestFixtures.user.id, isDeleted: true)))
        #expect(!member.canDelete(systemRow))

        let (_, admin) = await makeChat(role: .admin)
        #expect(admin.canDelete(other) && admin.canDelete(own))
    }
}
