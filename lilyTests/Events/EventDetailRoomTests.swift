import Foundation
import Testing
@testable import lily

/// The event detail's room seams: openChat fetches the room, places it in Mine and pushes it in place (the tournament
/// detail's recipe), and the participation writes keep Mine in step with the backend's room transaction.
@MainActor
struct EventDetailRoomTests {
    private let room = SportGroup.eventRoomFixture(id: "e", role: .member)
    private var upcoming: Date { EventDetailHarness.now.addingTimeInterval(3_600) }

    @Test func openChatFetchesTheRoomPlacesItInMineAndOpensItsChatInPlace() async {
        let harness = EventDetailHarness(event: .fixture(id: "e", startsAt: upcoming, isJoined: true))
        harness.groupRepository.result = .success([room])

        await harness.viewModel.openChat()

        #expect(harness.groupRepository.fetchedGroupIDs == ["e"])
        #expect(harness.viewModel.openedRoom == room, "the view pushes this chat on its own stack")
        #expect(harness.groups.groups.map(\.id) == ["e"])
        #expect(harness.errorCenter.current == nil)
    }

    /// Chat is for the involved (and behind its flag): an outsider's openChat fetches nothing and opens nothing.
    @Test func openChatNeedsTheChatPermission() async {
        let harness = EventDetailHarness(event: .fixture(id: "e", startsAt: upcoming))

        await harness.viewModel.openChat()

        #expect(harness.groupRepository.fetchedGroupIDs.isEmpty && harness.viewModel.openedRoom == nil)
    }

    /// A room the backend serves without the membership (a raced leave) opens but never enters Mine.
    @Test func openChatLeavesANonMemberRoomOutOfMine() async {
        let harness = EventDetailHarness(event: .fixture(id: "e", startsAt: upcoming, isJoined: true))
        harness.groupRepository.result = .success([SportGroup.eventRoomFixture(id: "e", role: nil)])

        await harness.viewModel.openChat()

        #expect(harness.viewModel.openedRoom != nil && harness.groups.groups.isEmpty)
    }

    /// A room the backend cannot answer (pre-backfill production, or a room the caller may not read) is the group
    /// 404: the popup speaks of the event's chat, never of a group.
    @Test func openChatRemapsAMissingRoomToTheEventsChatCopy() async {
        let harness = EventDetailHarness(event: .fixture(id: "e", startsAt: upcoming, isJoined: true))

        await harness.viewModel.openChat()

        #expect(harness.errorCenter.current?.error == .eventChatUnavailable)
        #expect(harness.viewModel.openedRoom == nil && harness.groups.groups.isEmpty)
        #expect(harness.logger.messages(in: .events, at: .warning).contains { $0.contains("Open chat for event e failed") },
                "the pre-backfill refusal is an expected product state")
        #expect(harness.logger.messages(in: .events, at: .error).isEmpty)
    }

    /// Only the missing room is remapped: any other failure keeps its own copy (offline stays offline).
    @Test func openChatPassesOtherFailuresThroughUnchanged() async {
        let harness = EventDetailHarness(event: .fixture(id: "e", startsAt: upcoming, isJoined: true))
        harness.groupRepository.thrownError = AppError.network

        await harness.viewModel.openChat()

        #expect(harness.errorCenter.current?.error == .network)
        #expect(harness.viewModel.openedRoom == nil)
    }

    /// A landed join reloads Mine and places the fetchable room, so Chats lists it without waiting for the index.
    @Test func aJoinReloadsMineAndPlacesTheFetchableRoom() async {
        let harness = EventDetailHarness(event: .fixture(id: "e", capacity: 4, participants: 1, startsAt: upcoming))
        harness.groupRepository.result = .success([room])

        await harness.viewModel.join()

        #expect(harness.viewModel.event.participates)
        #expect(harness.groupRepository.requestedScopes == [.mine], "Mine reloaded once")
        #expect(harness.groupRepository.fetchedGroupIDs == ["e"])
        #expect(harness.groups.groups.map(\.id) == ["e"])
    }

    /// Pre-backfill events have no room: the join stands, Mine's reload is all that ran, and nothing is reported.
    @Test func aJoinWithoutAFetchableRoomKeepsQuiet() async {
        let harness = EventDetailHarness(event: .fixture(id: "e", capacity: 4, participants: 1, startsAt: upcoming))
        harness.groupRepository.result = .success([])

        await harness.viewModel.join()

        #expect(harness.viewModel.event.participates)
        #expect(harness.groups.groups.isEmpty && harness.errorCenter.current == nil)
        #expect(harness.logger.messages(in: .events, at: .debug).contains { $0.contains("no fetchable room") })
    }

    /// A landed leave reloads Mine and drops the room whatever the eventually consistent index still answers.
    @Test func aLeaveReloadsMineAndDropsTheRoom() async {
        let event = SportEvent.fixture(id: "e", capacity: 4, participants: 2, startsAt: upcoming, isJoined: true)
        let harness = EventDetailHarness(event: event)
        harness.groups.add(room)
        harness.groupRepository.result = .success([room])

        await harness.viewModel.leave()

        #expect(!harness.viewModel.event.participates)
        #expect(harness.groupRepository.requestedScopes == [.mine], "Mine reloaded once")
        #expect(!harness.groups.groups.contains { $0.id == "e" }, "the room left Chats with the participation")
    }

    /// Opening a chat is a read: a room Mine already holds is not replaced (a stale fetch could regress its last
    /// message) and no change is recorded (Discover must not re-search for a mere open).
    @Test func openChatLeavesAHeldRoomUntouchedAndRecordsNoChange() async {
        let harness = EventDetailHarness(event: .fixture(id: "e", startsAt: upcoming, isJoined: true))
        let held = SportGroup.eventRoomFixture(id: "e", lastMessageAt: EventDetailHarness.now)
        harness.groups.add(held)
        harness.groupRepository.result = .success([SportGroup.eventRoomFixture(id: "e")])
        let version = harness.groupChanges.version

        await harness.viewModel.openChat()

        #expect(harness.viewModel.openedRoom != nil)
        #expect(harness.groups.groups == [held], "the held copy stands")
        #expect(harness.groupChanges.version == version, "no bump for a mere open")
    }

    /// The race the sync must lose gracefully: a Leave that lands while the join's room fetch is out owns the
    /// room's exit, so the sync never re-adds the left room (the fetch is parked to order the writes).
    @Test func aLeaveDuringTheJoinsRoomSyncKeepsTheRoomOutOfMine() async {
        let harness = EventDetailHarness(event: .fixture(id: "e", capacity: 4, participants: 1, startsAt: upcoming))
        harness.groupRepository.result = .success([room])
        harness.groupRepository.holdsFetches = true
        async let join: Void = harness.viewModel.join()
        while harness.groupRepository.fetchedGroupIDs.isEmpty { await Task.yield() }

        await harness.viewModel.leave()
        harness.groupRepository.releaseFetches()
        _ = await join

        #expect(!harness.viewModel.event.participates)
        #expect(!harness.groups.groups.contains { $0.id == "e" }, "the sync must not re-add the left room")
    }

    /// The mirror race: a join whose answer lands while the leave's reload is out keeps its room in Mine (the
    /// reload is parked; the competing join's read-back arrives through `accept`).
    @Test func aJoinThatLandedDuringTheLeavesReloadKeepsTheRoom() async {
        let event = SportEvent.fixture(id: "e", capacity: 4, participants: 2, startsAt: upcoming, isJoined: true)
        let harness = EventDetailHarness(event: event)
        harness.groups.add(room)
        harness.groupRepository.result = .success([room])
        harness.groupRepository.holdsRequests = true
        async let leave: Void = harness.viewModel.leave()
        while !harness.groupRepository.requestedScopes.contains(.mine) { await Task.yield() }

        harness.viewModel.accept(.fixture(id: "e", capacity: 4, participants: 2, startsAt: upcoming, isJoined: true))
        harness.groupRepository.releaseRequests()
        _ = await leave

        #expect(harness.groups.groups.contains { $0.id == "e" }, "the re-joined room stays in Mine")
    }
}
