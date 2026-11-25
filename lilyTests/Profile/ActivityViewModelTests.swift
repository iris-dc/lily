import Foundation
import Testing
@testable import lily

@MainActor
struct ActivityViewModelTests {
    private let events = FakeEventRepository()
    private let tournaments = FakeTournamentRepository()
    private let logger = SpyLogger()
    private let errorCenter: ErrorCenter

    init() {
        errorCenter = ErrorCenter(logger: logger)
    }

    private func makeViewModel() -> ActivityViewModel {
        ActivityViewModel(events: events, tournaments: tournaments, errorCenter: errorCenter, logger: logger)
    }

    @Test func loadReducesBothListsToSummariesLatestFirst() async {
        events.result = .success([.fixture(id: "g-1", title: "Older", startsAt: Date(timeIntervalSince1970: 1_000)),
                                  .fixture(id: "g-2", title: "Newer", startsAt: Date(timeIntervalSince1970: 2_000))])
        tournaments.result = .success([
            .fixture(id: "t-done", status: .completed, startsAt: Date(timeIntervalSince1970: 500)),
            .fixture(id: "t-open", status: .registration),
            .fixture(id: "t-cancelled", status: .cancelled),
            .fixture(id: "t-running", status: .inProgress),
        ])
        let viewModel = makeViewModel()

        await viewModel.load()

        #expect(viewModel.activity?.events.map(\.id) == ["g-2", "g-1"])
        #expect(viewModel.activity?.tournaments.map(\.id) == ["t-done"], "only a completed tournament is history")
    }

    @Test func loadAsksForPastGamesWithoutAPositionAndForMine() async {
        let viewModel = makeViewModel()

        await viewModel.load()

        #expect(events.requestedScopes == [.past] && events.requestedPositions == [nil])
        #expect(tournaments.requestedScopes == [.mine] && tournaments.requestedPositions == [nil])
    }

    @Test func aFailedLoadReachesThePopupAndOffersARetry() async {
        events.result = .failure(.eventsUnavailable)
        let viewModel = makeViewModel()

        await viewModel.load()

        #expect(viewModel.state == .failed)
        #expect(errorCenter.current?.error == .eventsUnavailable)
        #expect(logger.messages(in: .events, at: .error).count == 1)
    }

    /// A reload over a loaded history keeps it on screen while the popup reports the failure.
    @Test func aFailedReloadKeepsTheHistory() async {
        events.result = .success([.fixture(id: "g-1")])
        let viewModel = makeViewModel()
        await viewModel.load()

        events.result = .failure(.network)
        await viewModel.load()

        #expect(viewModel.activity?.events.map(\.id) == ["g-1"])
        #expect(errorCenter.current?.error == .network)
    }

    @Test func cancellationNeitherFailsTheScreenNorReports() async {
        events.thrownError = CancellationError()
        let viewModel = makeViewModel()

        await viewModel.load()

        #expect(viewModel.state == .loading)
        #expect(errorCenter.current == nil)
    }

    @Test func theOpenIsLoggedOncePerScreen() async {
        let viewModel = makeViewModel()

        await viewModel.load()
        await viewModel.load()

        #expect(logger.messages(in: .events, at: .info).mentioning("Activity opened").count == 1)
    }

    /// The mock wiring end to end: the fixtures' past games arrive as summaries, the latest first; no tournament has
    /// finished in the mock, so its history section says none yet.
    @Test func theMockWiringServesThePastFixtures() async {
        let viewModel = AppDependencies.makeMock().makeActivityViewModel()

        await viewModel.load()

        #expect(viewModel.activity?.events.map(\.id) == ["mock-event-past-0", "mock-event-past-1", "mock-event-past-2"])
        #expect(viewModel.activity?.tournaments.isEmpty == true)
    }
}
