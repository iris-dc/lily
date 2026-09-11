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

    /// Builds a view model over fakes; `replaced` records what it handed to the list.
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
                                             onChange: replacedEvents.record)
        }

        /// Lets a held request run until the view model is observably waiting on it.
        func waitUntilBusy() async {
            var attempts = 0
            while !viewModel.isBusy && attempts < 100 {
                await Task.yield()
                attempts += 1
            }
            #expect(viewModel.isBusy)
        }
    }

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

    @Test func leaveReplacesTheEventAndTellsTheList() async {
        let event = Self.makeEvent(capacity: 4, participants: 2, isJoined: true)
        let harness = Harness(event: event)

        await harness.viewModel.leave()

        #expect(harness.viewModel.event.participantCount == 1)
        #expect(harness.viewModel.participation == .join)
        #expect(harness.replaced == [harness.viewModel.event])
        #expect(harness.repository.leftEventIDs == [event.id])
    }

    @Test func failureKeepsTheEventAndReportsThroughTheErrorCenter() async {
        let event = Self.makeEvent(capacity: 4, participants: 4)
        let harness = Harness(event: event)
        harness.repository.participationError = AppError.eventFull

        await harness.viewModel.join()

        #expect(harness.viewModel.event == event)
        #expect(harness.replaced.isEmpty)
        #expect(harness.errorCenter.current?.error == .eventFull)
        #expect(!harness.viewModel.isBusy)
        #expect(harness.logger.messages(in: .events).contains { $0.contains("Join failed") })
    }

    @Test func transportFailureReachesThePopupAsNetwork() async {
        let harness = Harness(event: Self.makeEvent(capacity: 4, participants: 1))
        harness.repository.participationError = URLError(.notConnectedToInternet)

        await harness.viewModel.join()

        #expect(harness.errorCenter.current?.error == .network)
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
        await harness.waitUntilBusy()
        await harness.viewModel.leave()
        #expect(harness.repository.leftEventIDs.isEmpty)

        harness.repository.releaseRequests()
        await join.value
        #expect(!harness.viewModel.isBusy)
        #expect(harness.viewModel.event.participantCount == 2)
    }
}
