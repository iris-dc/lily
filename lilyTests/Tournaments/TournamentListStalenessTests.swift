import Foundation
import Testing
@testable import lily

/// When a tournament list reuses what it has, how long it waits after a failure, and what a load that is out does with
/// what lands meanwhile (a position, a change, a second call, a failure, the screen leaving): the twins of the events
/// list's staleness suites, over the `ContentFreshness` both lists share.
@MainActor
struct TournamentListStalenessTests {
    /// `berlin` and `nearby` round to the same coarse 52.52/13.40 the backend receives; `acrossTown` does not.
    nonisolated private static let berlin = Coordinate(latitude: 52.5231, longitude: 13.4049)
    nonisolated private static let nearby = Coordinate(latitude: 52.5235, longitude: 13.4040)
    nonisolated private static let acrossTown = Coordinate(latitude: 52.60, longitude: 13.40)
    /// The screen left mid-request, as the task's cancellation or as `URLSession` reports it. `nonisolated`:
    /// `@Test(arguments:)` reads it off the main actor.
    nonisolated private static let cancellations: [any Error] = [CancellationError(), URLError(.cancelled)]
    private let harness = TournamentHarness()
    private let center = AppConfig.Location.mockCenter

    /// Explore whose first load failed, with the backend answering one tournament from the next request on.
    private func makeFailedExplore(now: (() -> Date)? = nil) async -> TournamentListViewModel {
        harness.repository.result = .failure(.tournamentsUnavailable)
        let explore = harness.makeListViewModel(scope: .upcoming, now: now)
        await explore.loadIfStale()
        harness.repository.result = .success([.fixture()])
        return explore
    }

    /// Explore loaded once for `position`, which `service` answers, so the content is current for it.
    private func makeExploreLoaded(for position: Coordinate,
                                   service: FakeLocationService) async -> TournamentListViewModel {
        service.result = position
        let explore = harness.makeListViewModel(scope: .upcoming, locationService: service)
        await explore.loadUserLocation()
        await explore.loadIfStale()
        #expect(harness.repository.requestedPositions == [position])
        return explore
    }

    /// A refresh held by the fake while the user moves to `position` and the screen learns of it, then answered as the
    /// fake is scripted.
    private func refreshWhileMoving(_ explore: TournamentListViewModel,
                                    service: FakeLocationService,
                                    to position: Coordinate) async {
        harness.repository.holdsRequests = true
        let load = Task { await explore.load() }
        await settle(until: { explore.isLoading })
        service.result = position
        await explore.loadUserLocation()
        harness.repository.releaseRequests()
        await load.value
    }

    /// Switching tabs while the backend is down must not hammer it or repeat the popup: the retry waits for the
    /// cooldown, which the clock alone ends.
    @Test func aFailedLoadWaitsBeforeAskingAgain() async {
        var clock = TournamentHarness.now
        let explore = await makeFailedExplore(now: { clock })

        await explore.loadIfStale()
        await explore.loadIfStale()
        #expect(harness.repository.requestedScopes.count == 1)
        #expect(explore.loadFailed)
        #expect(harness.logger.messages(in: .cache).contains { $0.contains("not retrying yet") })

        clock = clock.addingTimeInterval(AppConfig.Lists.retryAfterFailure)
        await explore.loadIfStale()
        #expect(harness.repository.requestedScopes.count == 2)
        #expect(!explore.loadFailed)
        #expect(explore.tournaments.count == 1)
    }

    /// The cooldown is for a backend that is down; a change made elsewhere proves it is up and changes the answer.
    @Test func aChangeElsewhereEndsTheWaitEarly() async {
        let explore = await makeFailedExplore()

        harness.changes.recordChange()
        await explore.loadIfStale()

        #expect(harness.repository.requestedScopes.count == 2)
        #expect(!explore.loadFailed)
    }

    /// The position arrived while the first request was out, so that answer is in time order: asked again at once,
    /// and nothing extra while the request is out.
    @Test func aPositionArrivingMidLoadReloadsOnce() async {
        harness.repository.holdsRequests = true
        let service = FakeLocationService()
        service.result = center
        let explore = harness.makeListViewModel(scope: .upcoming, locationService: service)

        let load = Task { await explore.loadIfStale() }
        await settle(until: { explore.isLoading })
        await explore.loadUserLocation()
        #expect(harness.repository.requestedScopes.count == 1, "nothing extra while the request is out")
        harness.repository.releaseRequests()
        await load.value

        #expect(harness.repository.requestedPositions == [nil, center])
        #expect(!explore.isLoading)
    }

    /// Positions are compared as the backend receives them (`positionPrecision`, about a kilometre), so GPS drift
    /// between two fixes never reloads; a move past the rounding does, once.
    @Test func aMoveWithinTheRoundingIsNotAMove() async {
        let service = FakeLocationService()
        let explore = await makeExploreLoaded(for: Self.berlin, service: service)

        service.result = Self.nearby
        await explore.loadUserLocation()
        await explore.loadIfStale()
        #expect(harness.repository.requestedScopes.count == 1)

        service.result = Self.acrossTown
        await explore.loadUserLocation()
        await explore.loadIfStale()
        #expect(harness.repository.requestedScopes.count == 2)
        #expect(harness.logger.messages(in: .cache).contains { $0.contains("position changed") })
    }

    /// A move while a refresh is out that then fails earns no reload: the answer that never came is for no place, the
    /// popup shows once, and the cooldown is judged on the version and the caller, which a position does not end.
    @Test func aFailedLoadAfterASuccessNeverEarnsThePositionReload() async {
        let service = FakeLocationService()
        let explore = await makeExploreLoaded(for: center, service: service)
        harness.repository.result = .failure(.tournamentsUnavailable)

        await refreshWhileMoving(explore, service: service, to: TestFixtures.elsewhere)

        #expect(harness.repository.requestedPositions == [center, center])
        #expect(explore.loadFailed)
        #expect(harness.presentedError == .tournamentsUnavailable)

        await explore.loadIfStale()
        #expect(harness.repository.requestedPositions.count == 2)
    }

    /// A move while a refresh is out that is then cancelled (the screen left) earns no reload and no popup, only a
    /// debug line; the next appearance asks for the new place once.
    @Test(arguments: cancellations)
    func cancellationReloadsNothing(_ cancellation: any Error) async {
        let service = FakeLocationService()
        let explore = await makeExploreLoaded(for: center, service: service)
        harness.repository.thrownError = cancellation

        await refreshWhileMoving(explore, service: service, to: TestFixtures.elsewhere)

        #expect(harness.repository.requestedPositions == [center, center])
        #expect(!explore.loadFailed)
        #expect(harness.presentedError == nil)
        #expect(harness.logs(.debug).contains { $0.contains("cancelled for scope") })

        harness.repository.thrownError = nil
        await explore.loadIfStale()
        #expect(harness.repository.requestedPositions.count == 3)
        #expect(harness.repository.requestedPositions.last == TestFixtures.elsewhere)
    }

    /// Pull-to-refresh and an appearance while a request is out add nothing: the one request answers for all.
    @Test func aLoadInFlightDropsASecondCall() async {
        harness.repository.holdsRequests = true
        let explore = harness.makeListViewModel(scope: .upcoming)

        let first = Task { await explore.load() }
        await settle(until: { explore.isLoading })
        await explore.load()
        await explore.loadIfStale()
        #expect(harness.repository.requestedScopes.count == 1)
        harness.repository.releaseRequests()
        await first.value

        #expect(harness.repository.requestedScopes.count == 1)
        #expect(!explore.isLoading)
    }

    /// A change applied while a refresh was out may be missing from its answer, so the refresh asks once more on its
    /// own instead of showing that answer until the next appearance. The fake answers both requests from one snapshot,
    /// so the proof is the second request and that nothing stays stale after it.
    @Test func aRefreshInFlightReloadsOnceWhenAChangeLandedMeanwhile() async {
        harness.repository.holdsRequests = true
        let explore = harness.makeListViewModel(scope: .upcoming)

        let load = Task { await explore.load() }
        await settle(until: { harness.repository.requestedScopes.count == 1 })
        explore.replace(.fixture(id: "t", status: .cancelled))
        harness.repository.releaseRequests()
        await load.value
        #expect(harness.repository.requestedScopes.count == 2)
        #expect(!explore.isLoading)

        await explore.loadIfStale()
        #expect(harness.repository.requestedScopes.count == 2)
    }
}
