import Foundation
import Testing
@testable import lily

/// A room the caller lost. A page that lands after the room left the cache, because the caller was removed from the
/// group or signed out while the request was in flight, must not bring the room back; and a page the backend refused
/// because the caller is out of the group drops the group everywhere, not from the cache alone.
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

    /// A connected controller subscribed to the room, the room cached with `first` and its dot on, as Chats lists it.
    private func makeHarnessWithTheRoomCached() async -> (RealtimeHarness, ChatViewModel) {
        let harness = RealtimeHarness()
        harness.groups.result = .success([group])
        harness.cache.store(.fixture(messages: [first]), for: "g")
        await harness.connect()
        harness.unread.markUnread(groupID: "g", messageID: "m1")
        return (harness, harness.makeChatViewModel(for: group))
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

    /// `NOT_A_MEMBER` on the page: Mine (so the screens behind learn of the change), the cache, the dot, the
    /// subscription and the open room go at once, as they do when a `member_left` names the caller.
    @Test func aChatRefusalDropsTheGroupEverywhere() async {
        let (harness, viewModel) = await makeHarnessWithTheRoomCached()
        let version = harness.changes.version
        harness.chat.pageError = AppError.notAMember

        await viewModel.appear()

        #expect(viewModel.isGone && harness.cache.room(for: "g") == nil)
        #expect(harness.store.groups.isEmpty && harness.changes.version == version + 1)
        #expect(harness.controller.subscribedRooms["g"] == nil && harness.controller.openRoom == nil)
        #expect(!harness.unread.hasUnread(groupID: "g"))
        #expect(harness.chatLogs(.info).contains("Group g dropped (notAMember)"))
        #expect(harness.errorCenter.current?.error == .notAMember)
    }

    /// A lost connection says nothing about membership: the room stays listed, cached and subscribed.
    @Test func aNetworkFailureOnThePageKeepsTheGroup() async {
        let (harness, viewModel) = await makeHarnessWithTheRoomCached()
        harness.chat.pageError = AppError.network

        await viewModel.appear()

        #expect(!viewModel.isGone && harness.cache.room(for: "g") != nil)
        #expect(harness.store.groups.map(\.id) == ["g"])
        #expect(harness.controller.subscribedRooms["g"] == 1)
        #expect(harness.errorCenter.current?.error == .network)
    }
}
