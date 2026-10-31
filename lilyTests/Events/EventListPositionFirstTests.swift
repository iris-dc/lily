import Foundation
import Testing
@testable import lily

/// Explore's first request carries the user's position when the fix comes within `AppConfig.Location.firstFixWait`, and
/// content that is not the answer for the position is no "nothing matches" verdict.
@MainActor
struct EventListPositionFirstTests {
    private let repository = FakeEventRepository()
    private let location = FakeLocationService()
    private let sleep = HeldSleep()
    private let snapshots = InMemoryListSnapshotStore()
    private let key = ListSnapshotKey(list: "events-upcoming", userID: nil)
    private let berlin = [SportEvent.fixture(id: "berlin", startsAt: Date(timeIntervalSince1970: 1_800_000_000))]
    /// Far from every fixture, so the default radius hides them all.
    private let user = Coordinate(latitude: 50.06, longitude: 19.94)

    private func makeViewModel() -> EventListViewModel {
        makeEventListViewModel(repository: repository, locationService: location, sleep: sleep.sleep(for:), snapshots: snapshots)
    }

    private func screenState(of viewModel: EventListViewModel) -> EventListScreenState {
        .resolve(isInitialLoad: viewModel.isInitialLoad,
                 loadFailed: viewModel.loadFailed,
                 hasEvents: !viewModel.events.isEmpty,
                 isEverythingFilteredOut: viewModel.isEverythingFilteredOut,
                 awaitsAnswerForPosition: viewModel.awaitsAnswerForPosition)
    }

    @Test func aFixWithinTheWaitGoesOutWithTheFirstRequest() async {
        location.result = user
        let viewModel = makeViewModel()

        await viewModel.loadIfStaleNearTheUser()

        #expect(repository.requestedPositions == [user])
        #expect(sleep.requested == [AppConfig.Location.firstFixWait] && sleep.held.isEmpty)
    }

    /// A fix that takes longer holds nothing up: the list loads without it, and the fix reloads once when it lands.
    @Test func aFixPastTheWaitLoadsWithoutItAndReloadsWhenItLands() async {
        location.result = user
        location.holdsRequests = true
        let viewModel = makeViewModel()

        let load = Task { await viewModel.loadIfStaleNearTheUser() }
        await settle(until: { sleep.held.count == 1 })
        #expect(repository.requestedPositions.isEmpty)

        sleep.release()
        await settle(until: { repository.requestedPositions == [nil] })
        #expect(viewModel.hasLoaded && viewModel.userLocation == nil)

        location.releaseRequests()
        await load.value
        #expect(repository.requestedPositions == [nil, user] && viewModel.userLocation == user)
    }

    /// Without a fix (denied, or none yet) nothing waits twice: a later appearance asks again and loads at once.
    @Test func withoutAFixEveryAppearanceAsksAndLoads() async {
        let viewModel = makeViewModel()

        await viewModel.loadIfStaleNearTheUser()

        #expect(repository.requestedPositions == [nil] && location.callCount == 1)
    }

    /// The snapshot (one launch's answer, for whatever position) with the fix known: the filter hiding all of it is the
    /// spinner, not "nothing matches", until the answer for the position lands.
    @Test func aSnapshotHiddenByTheFilterShowsTheSpinnerUntilTheAnswerForThePosition() async {
        snapshots.seed(berlin, for: key)
        location.result = user
        repository.result = .success([])
        repository.holdsRequests = true
        let viewModel = makeViewModel()
        #expect(!viewModel.awaitsAnswerForPosition && screenState(of: viewModel) == .list, "no position yet")

        let load = Task { await viewModel.loadIfStaleNearTheUser() }
        await settle(until: { repository.requestedPositions == [user] })
        #expect(viewModel.awaitsAnswerForPosition && viewModel.isEverythingFilteredOut)
        #expect(screenState(of: viewModel) == .loading)

        repository.releaseRequests()
        await load.value
        #expect(!viewModel.awaitsAnswerForPosition && screenState(of: viewModel) == .empty)
    }

    /// An answer loaded for no position is not the one for the position that lands later either; a failed load ends
    /// the wait, so the screen says so instead of spinning.
    @Test func anAnswerForAnotherPositionAwaitsTheReloadAndAFailureEndsTheWait() async {
        repository.result = .success(berlin)
        let viewModel = makeViewModel()
        await viewModel.loadIfStaleNearTheUser()
        #expect(!viewModel.awaitsAnswerForPosition && screenState(of: viewModel) == .list)

        location.result = user
        repository.holdsRequests = true
        let reload = Task { await viewModel.loadUserLocation() }
        await settle(until: { repository.requestedPositions == [nil, user] })
        #expect(viewModel.awaitsAnswerForPosition && screenState(of: viewModel) == .loading)

        repository.thrownError = AppError.network
        repository.releaseRequests()
        await reload.value
        #expect(!viewModel.awaitsAnswerForPosition && viewModel.loadFailed)
        #expect(screenState(of: viewModel) == .filteredOut)
    }
}
