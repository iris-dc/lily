import Foundation
import Testing
@testable import lily

/// The detail on a game that allows extra players. The main detail suite is at its type-body limit.
@MainActor
struct EventDetailCapacityTests {
    /// Reaching the number needed is not reaching capacity: the game stays open, so the key event is not logged.
    @Test func aJoinThatMeetsTheNumberNeededDoesNotLogCapacityReached() async {
        let harness = EventDetailHarness(
            event: .fixture(capacity: 2, allowsExtraParticipants: true, participants: 1, hostUserId: "host"))

        await harness.viewModel.join()

        #expect(harness.viewModel.event.hasPlayersNeeded && !harness.viewModel.event.isFull)
        #expect(harness.viewModel.participation == .leave)
        #expect(!harness.logger.messages(in: .events).contains { $0.contains("Capacity reached") })
    }
}
