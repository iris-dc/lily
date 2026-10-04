import Foundation
import Testing
@testable import lily

/// `tournament_changed` and `match_updated` on a tournament's room: the tournament change counter moves (the screens
/// refetch), a change's newer epoch is adopted, and an event for another tournament on the room is dropped.
@MainActor
struct RealtimeTournamentRoutingTests {
    private let roomID = "t1"
    private let room = RealtimeChannel.room(groupID: "t1", epoch: 1)

    private func connected() async -> RealtimeHarness {
        let harness = RealtimeHarness()
        harness.groups.result = .success([.tournamentRoomFixture(id: roomID)])
        await harness.connect()
        return harness
    }

    @Test func aTournamentChangeAndAMatchUpdateBumpTheTournamentCounter() async {
        let harness = await connected()
        let change = TournamentChange(tournamentId: roomID, status: .inProgress, entryCount: 5, channelEpoch: 1)
        let match = TournamentMatch(id: "r01p001", tournamentId: roomID, round: 1, position: 1, status: .scheduled)

        harness.transport.post(.tournamentChanged(change), to: room)
        await settle(until: { harness.tournamentChanges.version == 1 })
        harness.transport.post(.matchUpdated(match), to: room)
        await settle(until: { harness.tournamentChanges.version == 2 })

        #expect(harness.changes.version == 0, "Mine did not move")
        #expect(harness.controller.subscribedEpoch(for: roomID) == 1, "the same epoch stays subscribed")
    }

    @Test func aChangeWithANewerEpochResubscribes() async {
        let harness = await connected()
        let change = TournamentChange(tournamentId: roomID, status: .registration, entryCount: 6, channelEpoch: 2)

        harness.transport.post(.tournamentChanged(change), to: room)
        await settle(until: { harness.controller.subscribedEpoch(for: roomID) == 2 })

        #expect(harness.tournamentChanges.version == 1)
        #expect(harness.chatLogs(.info).contains("Epoch changed for group t1: 1 -> 2"))
    }

    @Test func aChangeForAnotherTournamentOnTheRoomIsDropped() async {
        let harness = await connected()
        let other = TournamentChange(tournamentId: "t9", status: .completed, entryCount: 4, channelEpoch: 1)

        harness.transport.post(.tournamentChanged(other), to: room)
        await settle(until: { harness.chatLogs(.warning).contains { $0.contains("another group on rooms/t1/1") } })

        #expect(harness.tournamentChanges.version == 0)
    }
}
