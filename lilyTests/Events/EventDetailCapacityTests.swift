import Foundation
import Testing
@testable import lily

/// The detail on a game that allows extra players. The main detail suite is at its type-body limit.
@MainActor
struct EventDetailCapacityTests {
    private let repository = FakeEventRepository()
    private let logger = SpyLogger()

    private func makeViewModel(event: SportEvent) -> EventDetailViewModel {
        repository.result = .success([event])
        return EventDetailViewModel(event: event,
                                    repository: repository,
                                    identity: FakeIdentityProvider(currentUserID: TestFixtures.user.id),
                                    errorCenter: ErrorCenter(logger: logger),
                                    recorder: SpyInteractionRecorder(),
                                    logger: logger,
                                    tryAgainDelay: .zero,
                                    onChange: { _ in })
    }

    /// Reaching the number needed is not reaching capacity: the game stays open, so the key event is not logged.
    @Test func aJoinThatMeetsTheNumberNeededDoesNotLogCapacityReached() async {
        let viewModel = makeViewModel(
            event: .fixture(capacity: 2, allowsExtraParticipants: true, participants: 1, hostUserId: "host"))

        await viewModel.join()

        #expect(viewModel.event.hasPlayersNeeded && !viewModel.event.isFull)
        #expect(viewModel.participation == .leave)
        #expect(!logger.messages(in: .events).contains { $0.contains("Capacity reached") })
    }

    /// Past the number needed, or without any limit, the control is still Join, never "Event is full".
    @Test func aCrowdedOrUnlimitedGameStillOffersJoin() {
        let crowded = makeViewModel(
            event: .fixture(capacity: 2, allowsExtraParticipants: true, participants: 5, hostUserId: "host"))
        let unlimited = makeViewModel(event: .fixture(capacity: nil, participants: 50, hostUserId: "host"))

        #expect(crowded.participation == .join && unlimited.participation == .join)
    }
}
