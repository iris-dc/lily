import Foundation
import Testing
@testable import lily

@MainActor
struct EventDetailViewModelTests {
    /// What the view model handed to the list through `onChange`.
    @MainActor private final class ReplacedEvents {
        private(set) var events: [SportEvent] = []

        func record(_ event: SportEvent) {
            events.append(event)
        }
    }

    /// Builds a view model over fakes; `replaced` records what it handed to the list. The retry pause is zero so
    /// no test waits on a clock.
    @MainActor private final class Harness {
        let repository = FakeEventRepository()
        let identity = FakeIdentityProvider(currentUserID: TestFixtures.user.id)
        let logger = SpyLogger()
        let errorCenter: ErrorCenter
        let viewModel: EventDetailViewModel
        private let replacedEvents = ReplacedEvents()

        var replaced: [SportEvent] { replacedEvents.events }

        init(event: SportEvent) {
            errorCenter = ErrorCenter(logger: logger)
            repository.result = .success([event])
            viewModel = EventDetailViewModel(event: event,
                                             repository: repository,
                                             identity: identity,
                                             errorCenter: errorCenter,
                                             logger: logger,
                                             tryAgainDelay: .zero,
                                             onChange: replacedEvents.record)
        }
    }

    /// Refusals that mean the event moved on under the caller: expected product states, logged as warnings.
    /// `nonisolated`: `@Test(arguments:)` reads it off the main actor.
    nonisolated private static let conflicts: [AppError] = [
        .eventFull, .alreadyJoined, .notAParticipant, .hostCannotLeave, .tryAgain,
    ]
    /// Failures that leave the outcome unknown (a 500 after a committed write; a lost connection, which is what the
    /// repository makes of a transport failure): app faults, logged as errors.
    nonisolated private static let unknownOutcomes: [AppError] = [.participationFailed, .network]
    /// Every failure after which the detail fetches the event again.
    nonisolated private static let refreshTriggers = conflicts + unknownOutcomes

    private static func makeEvent(capacity: Int,
                                  participants: Int,
                                  hostUserId: String? = "host",
                                  isJoined: Bool? = false) -> SportEvent {
        .fixture(capacity: capacity, participants: participants, hostUserId: hostUserId, isJoined: isJoined)
    }

    @Test func participationFollowsTheCallerAndTheEvent() {
        let open = Self.makeEvent(capacity: 4, participants: 1)
        #expect(Participation(event: open, userID: nil) == .hidden)
        #expect(Participation(event: open, userID: "u-1") == .join)
        #expect(Participation(event: Self.makeEvent(capacity: 4, participants: 2, isJoined: true), userID: "u-1") == .leave)
        #expect(Participation(event: Self.makeEvent(capacity: 4, participants: 4), userID: "u-1") == .full)
        #expect(Participation(event: Self.makeEvent(capacity: 4, participants: 4, isJoined: true), userID: "u-1") == .leave)
        #expect(Participation(event: Self.makeEvent(capacity: 4, participants: 4, hostUserId: "u-1", isJoined: true),
                              userID: "u-1") == .hosting)
        #expect(Participation(event: Self.makeEvent(capacity: 4, participants: 1, hostUserId: nil), userID: nil) == .hidden)
    }

    @Test func viewModelReadsTheIdentityLive() {
        let harness = Harness(event: Self.makeEvent(capacity: 4, participants: 1))
        #expect(harness.viewModel.participation == .join)

        harness.identity.currentUserID = nil
        #expect(harness.viewModel.participation == .hidden)

        harness.identity.currentUserID = "host"
        #expect(harness.viewModel.participation == .hosting)
    }

    @Test func joinReplacesTheEventAndTellsTheList() async {
        let event = Self.makeEvent(capacity: 4, participants: 1)
        let harness = Harness(event: event)

        await harness.viewModel.join()

        #expect(harness.viewModel.event.participantCount == 2)
        #expect(harness.viewModel.participation == .leave)
        #expect(harness.replaced == [harness.viewModel.event])
        #expect(harness.repository.joinedEventIDs == [event.id])
        #expect(!harness.viewModel.isBusy)
        #expect(harness.errorCenter.current == nil)
        #expect(harness.logger.messages(in: .events).contains { $0.contains("Join succeeded") && $0.contains("2/4") })
    }

    /// "Capacity reached" is a key event of its own, so a full game can be found in the log without reading numbers.
    @Test func aJoinThatFillsTheEventLogsCapacityReached() async {
        let event = Self.makeEvent(capacity: 2, participants: 1)
        let harness = Harness(event: event)

        await harness.viewModel.join()

        #expect(harness.viewModel.event.isFull)
        let capacityLines = harness.logger.messages(in: .events, at: .info).filter { $0.contains("Capacity reached") }
        #expect(capacityLines == ["Capacity reached for event \(event.id)"])
    }

    @Test func aJoinThatLeavesRoomDoesNotLogCapacityReached() async {
        let harness = Harness(event: Self.makeEvent(capacity: 4, participants: 1))

        await harness.viewModel.join()

        #expect(!harness.logger.messages(in: .events).contains { $0.contains("Capacity reached") })
    }

    @Test func leaveReplacesTheEventAndTellsTheList() async {
        let event = Self.makeEvent(capacity: 4, participants: 2, isJoined: true)
        let harness = Harness(event: event)

        await harness.viewModel.leave()

        #expect(harness.viewModel.event.participantCount == 1)
        #expect(harness.viewModel.participation == .join)
        #expect(harness.replaced == [harness.viewModel.event])
        #expect(harness.repository.leftEventIDs == [event.id])
    }

    /// A refusal is an expected product state and stays a warning; a failure of unknown outcome is an app fault.
    @Test(arguments: conflicts)
    func aRefusalIsLoggedAsAWarning(error: AppError) async {
        let harness = Harness(event: Self.makeEvent(capacity: 4, participants: 1))
        harness.repository.participationError = error

        await harness.viewModel.join()

        #expect(harness.logger.messages(in: .events, at: .warning).contains { $0.contains("Join failed") })
        #expect(harness.logger.messages(in: .events, at: .error).isEmpty)
    }

    @Test(arguments: unknownOutcomes)
    func aFailureOfUnknownOutcomeIsLoggedAsAnError(error: AppError) async {
        let harness = Harness(event: Self.makeEvent(capacity: 4, participants: 1))
        harness.repository.participationError = error

        await harness.viewModel.join()

        #expect(harness.logger.messages(in: .events, at: .error).contains { $0.contains("Join failed") })
    }

    /// The screen showed 1 of 4 while the server already had 4 of 4: after the refusal the detail and the list
    /// behind it show the server's numbers, and the popup explains why the tap did nothing. A 500 or a lost
    /// connection may hide a committed join, so those refetch too.
    @Test(arguments: refreshTriggers)
    func aRefusalOrAnUnknownOutcomeRefreshesTheEventAndTellsTheList(error: AppError) async {
        let stale = Self.makeEvent(capacity: 4, participants: 1)
        let fresh = stale.updatingParticipation(count: 4, isJoined: false)
        let harness = Harness(event: stale)
        harness.repository.result = .success([fresh])
        harness.repository.participationError = error

        await harness.viewModel.join()

        #expect(harness.viewModel.event == fresh)
        #expect(harness.replaced == [fresh])
        #expect(harness.repository.fetchedEventIDs == [stale.id])
        #expect(harness.repository.joinedEventIDs.count == (error == .tryAgain ? 2 : 1))
        #expect(harness.errorCenter.current?.error == error)
        #expect(!harness.viewModel.isBusy)
    }

    /// The refusal is what the user needs to hear; a refetch that fails on top of it is a log line.
    /// The refetch shows the write did land (Laurel commits before it reads back): the screen is right, and a popup
    /// telling the user to try again would only earn them an "already joined" refusal, so there is none.
    @Test(arguments: unknownOutcomes)
    func anUnknownOutcomeWhoseWriteLandedShowsNoPopup(error: AppError) async {
        let stale = Self.makeEvent(capacity: 4, participants: 1)
        let landed = stale.updatingParticipation(count: 2, isJoined: true)
        let harness = Harness(event: stale)
        harness.repository.result = .success([landed])
        harness.repository.participationError = error

        await harness.viewModel.join()

        #expect(harness.viewModel.event == landed)
        #expect(harness.replaced == [landed])
        #expect(harness.errorCenter.current == nil)
        #expect(harness.logger.messages(in: .events).contains { $0.contains("landed for event") })
    }

    /// A refusal is never silenced by the refetch, even one whose fresh event already shows the caller in.
    @Test func aRefusalStaysReportedEvenWhenTheCallerIsIn() async {
        let stale = Self.makeEvent(capacity: 4, participants: 1)
        let joined = stale.updatingParticipation(count: 2, isJoined: true)
        let harness = Harness(event: stale)
        harness.repository.result = .success([joined])
        harness.repository.participationError = AppError.alreadyJoined

        await harness.viewModel.join()

        #expect(harness.viewModel.event == joined)
        #expect(harness.errorCenter.current?.error == .alreadyJoined)
    }

    @Test(arguments: refreshTriggers)
    func aFailedRefreshKeepsTheEventAndStillReportsTheFailure(error: AppError) async {
        let stale = Self.makeEvent(capacity: 4, participants: 1)
        let harness = Harness(event: stale)
        harness.repository.participationError = error
        harness.repository.result = .failure(.network)

        await harness.viewModel.join()

        #expect(harness.viewModel.event == stale)
        #expect(harness.replaced.isEmpty)
        #expect(harness.repository.fetchedEventIDs == [stale.id])
        #expect(harness.errorCenter.current?.error == error)
        #expect(!harness.viewModel.isBusy)
        #expect(harness.logger.messages(in: .events, at: .warning).contains { $0.contains("Could not refresh") })
    }

    /// A lost race is the backend's business, not the user's: the request is repeated once and succeeds quietly.
    @Test func aLostRaceIsRetriedOnceWithoutAPopup() async {
        let event = Self.makeEvent(capacity: 4, participants: 1)
        let harness = Harness(event: event)
        harness.repository.nextParticipationError = AppError.tryAgain

        await harness.viewModel.join()

        #expect(harness.repository.joinedEventIDs == [event.id, event.id])
        #expect(harness.viewModel.event.participantCount == 2)
        #expect(harness.replaced == [harness.viewModel.event])
        #expect(harness.repository.fetchedEventIDs.isEmpty)
        #expect(harness.errorCenter.current == nil)
        #expect(harness.logger.messages(in: .events).contains { $0.contains("retrying once") })
    }

    @Test func cancellationIsQuiet() async {
        for cancellation: any Error in [CancellationError(), URLError(.cancelled)] {
            let harness = Harness(event: Self.makeEvent(capacity: 4, participants: 1))
            harness.repository.participationError = cancellation

            await harness.viewModel.join()

            #expect(harness.errorCenter.current == nil)
            #expect(harness.replaced.isEmpty)
        }
    }

    @Test func secondActionIsDroppedWhileTheFirstRuns() async {
        let harness = Harness(event: Self.makeEvent(capacity: 4, participants: 1))
        harness.repository.holdsRequests = true

        let join = Task { await harness.viewModel.join() }
        await settle(until: { harness.viewModel.isBusy })
        await harness.viewModel.leave()
        #expect(harness.repository.leftEventIDs.isEmpty)

        harness.repository.releaseRequests()
        await join.value
        #expect(!harness.viewModel.isBusy)
        #expect(harness.viewModel.event.participantCount == 2)
    }
}
