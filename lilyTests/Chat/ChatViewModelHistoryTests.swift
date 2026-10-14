import Foundation
import Testing
@testable import lily

/// Paging back through a room: one older page in flight at a time, refused when the room moved under it, and shared
/// with a quote tap that needs the same page.
@MainActor
struct ChatViewModelHistoryTests {
    private let group = SportGroup.fixture(id: "g", channelEpoch: 1, role: .member)

    /// A connected controller, the room cached as given and the chat open.
    private func makeOpenChat(room: ChatRoomState) async -> (RealtimeHarness, ChatViewModel) {
        let harness = RealtimeHarness()
        harness.groups.result = .success([group])
        harness.cache.store(room, for: "g")
        await harness.connect()
        let viewModel = harness.makeChatViewModel(for: group)
        await viewModel.appear()
        return (harness, viewModel)
    }

    /// A room holding "m0001" up to "m\(count)" with history before them; one over the cache limit, so that a
    /// compaction drops its oldest row and the anchor of the page before moves.
    private func room(holding count: Int = AppConfig.Chat.roomCacheLimit + 1) -> ChatRoomState {
        var room = ChatRoomState(groupID: "g", channelEpoch: 1)
        room.applyNewest(.fixture(messages(1...count), hasMore: true))
        return room
    }

    private func messages(_ indices: ClosedRange<Int>) -> [ChatMessage] {
        indices.map { .fixture(id: String(format: "m%04d", $0)) }
    }

    /// The request for the page before "m0001" ("m0000" alone) is held in flight; the load to await comes back.
    private func holdOlderPage(of viewModel: ChatViewModel, in harness: RealtimeHarness) async -> Task<Bool, Never> {
        harness.chat.olderPages = [.fixture(messages(0...0), hasMore: true)]
        harness.chat.holdsRequests = true
        let load = Task { await viewModel.loadOlder() }
        await settle(until: { harness.chat.olderRequests.count == 1 })
        return load
    }

    /// Back during the request: `cancel()` compacts the room to the cache limit, which drops "m0001" and moves the
    /// anchor to "m0002"; the page asked for before "m0001" would sit below a hole, so it is refused.
    @Test func anOlderPageForAMovedAnchorIsDropped() async {
        let (harness, viewModel) = await makeOpenChat(room: room())
        let load = await holdOlderPage(of: viewModel, in: harness)
        #expect(harness.chat.olderRequests.map(\.before) == ["m0001"])

        await viewModel.cancel()
        harness.chat.releaseRequests()

        #expect(await !load.value, "nothing was prepended")
        #expect(viewModel.room.messages.count == AppConfig.Chat.roomCacheLimit && viewModel.room.oldestID == "m0002")
        #expect(harness.chatLogs(.debug).contains { $0.hasPrefix("Older page before m0001 dropped") })
        #expect(!viewModel.isLoadingOlder)
    }

    @Test func anOlderPageForTheCurrentAnchorIsPrepended() async {
        let (harness, viewModel) = await makeOpenChat(room: room())
        let load = await holdOlderPage(of: viewModel, in: harness)

        harness.chat.releaseRequests()

        #expect(await load.value, "a row not held before arrived")
        #expect(viewModel.room.messages.count == AppConfig.Chat.roomCacheLimit + 2 && viewModel.room.oldestID == "m0000")
        #expect(!harness.chatLogs(.debug).contains { $0.hasPrefix("Older page before") })
    }

    /// A tap on a quote while the transcript's own older page is in flight waits for that page and looks again,
    /// instead of asking beside it or giving up; the pages it asks for itself follow once the hold is off.
    @Test func aQuoteTapWaitsForTheOlderPageInFlight() async {
        let (m3, m4, m5) = (ChatMessage.fixture(id: "m3"), ChatMessage.fixture(id: "m4"), ChatMessage.fixture(id: "m5"))
        var room = ChatRoomState(groupID: "g", channelEpoch: 1)
        room.applyNewest(.fixture([m5], hasMore: true))
        let (harness, viewModel) = await makeOpenChat(room: room)
        harness.chat.olderPages = [.fixture([m4], hasMore: true), .fixture([m3], hasMore: true)]
        harness.chat.holdsRequests = true
        let transcriptLoad = Task { await viewModel.loadOlder() }
        await settle(until: { harness.chat.olderRequests.count == 1 })

        let reveal = Task { await viewModel.revealQuoted(id: "m3") }
        await harness.yield()
        #expect(harness.chat.olderRequests.count == 1, "the tap waits for the page in flight")
        harness.chat.releaseRequests()

        #expect(await reveal.value, "the original is here to scroll to")
        #expect(await transcriptLoad.value)
        #expect(harness.chat.olderRequests.map(\.before) == ["m5", "m4"])
        #expect(viewModel.room.messages.map(\.id) == ["m3", "m4", "m5"] && !viewModel.isLoadingOlder)
    }
}
