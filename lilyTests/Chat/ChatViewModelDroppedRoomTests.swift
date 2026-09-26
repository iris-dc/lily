import Foundation
import Testing
@testable import lily

/// A page that lands after the room left the cache, because the caller was removed from the group or signed out while
/// the request was in flight: the late answer must not bring the room back.
@MainActor
struct ChatViewModelDroppedRoomTests {
    private let group = SportGroup.fixture(id: "g", channelEpoch: 1, role: .member)
    private let first = ChatMessage.fixture(id: "m1")
    private let second = ChatMessage.fixture(id: "m2")

    /// A connected controller subscribed to the room, a cached room with a page before it, and that page held in flight.
    private func makeHarnessLoadingOlder() async -> (RealtimeHarness, Task<Bool, Never>) {
        let harness = RealtimeHarness()
        harness.groups.result = .success([group])
        var room = ChatRoomState(groupID: "g", channelEpoch: 1)
        room.applyNewest(.fixture([second], hasMore: true))
        harness.cache.store(room, for: "g")
        await harness.connect()
        let viewModel = harness.makeChatViewModel(for: group)
        harness.chat.olderPages = [.fixture([first])]
        harness.chat.holdsRequests = true
        let loading = Task { await viewModel.loadOlder() }
        await settle(until: { harness.chat.olderRequests.count == 1 })
        return (harness, loading)
    }

    @Test func anOlderPageLandingAfterTheCallerWasRemovedDoesNotRecreateTheRoom() async {
        let (harness, loading) = await makeHarnessLoadingOlder()
        harness.transport.post(.memberLeft(groupID: "g", userID: TestFixtures.user.id, channelEpoch: 2, memberCount: 5),
                               to: .room(groupID: "g", epoch: 1))
        await settle(until: { harness.cache.room(for: "g") == nil })

        harness.chat.releaseRequests()

        #expect(await !loading.value, "nothing was prepended")
        #expect(harness.cache.room(for: "g") == nil)
    }

    @Test func anOlderPageLandingAfterSignOutDoesNotRecreateTheRoom() async {
        let (harness, loading) = await makeHarnessLoadingOlder()
        harness.cache.sessionDidEnd()

        harness.chat.releaseRequests()

        #expect(await !loading.value)
        #expect(harness.cache.cachedGroupIDs.isEmpty)
    }
}
