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
        let changes = EventChangeTracker()
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
