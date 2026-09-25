import Foundation
import Testing
@testable import lily

/// When `loadIfStale()` reuses what a list already has, when it reloads, and how long it waits after a failure.
@MainActor
struct EventListStalenessTests {
    @Test func loadIfStaleReusesEventsUntilTheyExpire() async {
        let repository = FakeEventRepository()
        repository.result = .success(MockEventFixtures.make(now: .now, count: 2))
        var clock = Date(timeIntervalSince1970: 1_700_000_000)
        let viewModel = makeEventListViewModel(repository: repository, now: { clock })

        await viewModel.loadIfStale()
        await viewModel.loadIfStale()
        #expect(repository.requestedScopes.count == 1)

        clock = clock.addingTimeInterval(AppConfig.Events.listStaleAfter)
        await viewModel.loadIfStale()
        #expect(repository.requestedScopes.count == 2)
    }

    /// A debugging session must be able to tell a hit from a miss, and why the miss happened.
    @Test func loadIfStaleLogsWhyItReloads() async {
        let repository = FakeEventRepository()
        let logger = SpyLogger()
        var clock = Date(timeIntervalSince1970: 1_700_000_000)
        let viewModel = makeEventListViewModel(repository: repository, logger: logger, now: { clock })

        await viewModel.loadIfStale()
        #expect(logger.messages(in: .cache).contains { $0.contains("never loaded") })

        clock = clock.addingTimeInterval(AppConfig.Events.listStaleAfter)
        await viewModel.loadIfStale()
        #expect(logger.messages(in: .cache).contains { $0.contains("older than TTL") })
    }

    /// Switching tabs while the backend is down must not hammer it or repeat the popup; the retry waits for the
    /// cooldown. Pull-to-refresh (`load()`) is not held back.
    /// The cooldown is for a backend that is down; a join made elsewhere proves it is up and changes the answer.
    @Test func aChangeElsewhereEndsTheRetryCooldownEarly() async {
        let repository = FakeEventRepository()
        repository.result = .failure(.network)
        let changes = ChangeTracker()
        let clock = Date(timeIntervalSince1970: 1_700_000_000)
        let viewModel = makeEventListViewModel(repository: repository, changes: changes, now: { clock })
        await viewModel.loadIfStale()
        repository.result = .success(MockEventFixtures.make(now: .now, count: 1))

        changes.recordChange()
        await viewModel.loadIfStale()

        #expect(repository.requestedScopes.count == 2)
        #expect(!viewModel.loadFailed)
    }

    /// Same for a sign-in or sign-out: `isJoined` is per caller, so the failed answer would be wrong anyway.
    @Test func aChangeOfCallerEndsTheRetryCooldownEarly() async {
        let repository = FakeEventRepository()
        repository.result = .failure(.network)
        let identity = FakeIdentityProvider()
        let clock = Date(timeIntervalSince1970: 1_700_000_000)
        let viewModel = makeEventListViewModel(repository: repository, identity: identity, now: { clock })
        await viewModel.loadIfStale()
        repository.result = .success(MockEventFixtures.make(now: .now, count: 1))

        identity.currentUserID = TestFixtures.user.id
        await viewModel.loadIfStale()

        #expect(repository.requestedScopes.count == 2)
    }

    /// Explore loaded before the position was known is in plain time order; once known, one reload lets the backend
    /// order by distance. One: the second load carries the position, so the content is not stale for it again.
    @Test func exploreReloadsOnceWhenThePositionBecomesKnown() async {
        let repository = FakeEventRepository()
        let service = FakeLocationService()
        let logger = SpyLogger()
        let viewModel = makeEventListViewModel(repository: repository, locationService: service, logger: logger)
        await viewModel.loadIfStale()
        #expect(repository.requestedPositions == [nil])

        service.result = AppConfig.Location.mockCenter
        await viewModel.loadUserLocation()
        #expect(repository.requestedPositions == [nil, AppConfig.Location.mockCenter])
        #expect(logger.messages(in: .cache).contains { $0.contains("position became known") })

        await viewModel.loadIfStale()
        #expect(repository.requestedScopes.count == 2)
    }

    @Test func noReloadWhenTheFirstLoadAlreadyHadThePosition() async {
        let repository = FakeEventRepository()
        let service = FakeLocationService()
        service.result = AppConfig.Location.mockCenter
        let viewModel = makeEventListViewModel(repository: repository, locationService: service)

        await viewModel.loadUserLocation()
        await viewModel.loadIfStale()
        await viewModel.loadIfStale()

        #expect(repository.requestedPositions == [AppConfig.Location.mockCenter])
    }

    /// The position arrived while the first request was out, so that answer is in time order: asked again at once.
    @Test func aPositionArrivingMidLoadEarnsOneReload() async {
        let repository = FakeEventRepository()
        repository.holdsRequests = true
        let service = FakeLocationService()
        service.result = AppConfig.Location.mockCenter
        let viewModel = makeEventListViewModel(repository: repository, locationService: service)

        let load = Task { await viewModel.loadIfStale() }
        await settle(until: { viewModel.isLoading })
        await viewModel.loadUserLocation()
        #expect(repository.requestedScopes.count == 1, "nothing extra while the request is out")
        repository.releaseRequests()
        await load.value

        #expect(repository.requestedPositions == [nil, AppConfig.Location.mockCenter])
        #expect(!viewModel.isLoading)
    }

    /// My Events is the caller's own games in start order; a position changes nothing there.
    @Test func joinedNeverReloadsForAPosition() async {
        let repository = FakeEventRepository()
        let service = FakeLocationService()
        let viewModel = makeEventListViewModel(scope: .joined, repository: repository, locationService: service)
        await viewModel.loadIfStale()

        service.result = AppConfig.Location.mockCenter
        await viewModel.loadUserLocation()
        await viewModel.loadIfStale()

        #expect(repository.requestedPositions == [nil])
    }

    @Test func loadIfStaleRetriesAFailureOnlyAfterTheCooldown() async {
        let repository = FakeEventRepository()
        repository.result = .failure(.network)
        var clock = Date(timeIntervalSince1970: 1_700_000_000)
        let viewModel = makeEventListViewModel(repository: repository, now: { clock })
        await viewModel.loadIfStale()

        repository.result = .success(MockEventFixtures.make(now: .now, count: 1))
        await viewModel.loadIfStale()
        await viewModel.loadIfStale()
        #expect(repository.requestedScopes.count == 1)
        #expect(viewModel.loadFailed)

        clock = clock.addingTimeInterval(AppConfig.Events.retryAfterFailure)
        await viewModel.loadIfStale()
        #expect(repository.requestedScopes.count == 2)
        #expect(viewModel.events.count == 1)
        #expect(!viewModel.loadFailed)
    }
}
