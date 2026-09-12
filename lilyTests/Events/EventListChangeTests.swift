import Foundation
import Testing
@testable import lily

/// How a participation change made on the detail screen, or a change of caller, reaches the lists behind it.
@MainActor
struct EventListChangeTests {
    private let events = MockEventFixtures.make(now: .now, count: 3)

    /// A guest signing in, and a user signing out: `isJoined` is the server's answer for the caller, so both stale.
    /// `nonisolated`: `@Test(arguments:)` reads it off the main actor.
    nonisolated private static let identityChanges: [(before: String?, after: String?)] = [(nil, "u-1"), ("u-1", nil)]

    private func makeRepository() -> FakeEventRepository {
        let repository = FakeEventRepository()
        repository.result = .success(events)
        return repository
    }

    @Test func replaceUpdatesTheEventInPlace() async {
        let viewModel = makeEventListViewModel(repository: makeRepository())
        await viewModel.load()
        let changed = events[1].updatingParticipation(count: events[1].participantCount + 1, isJoined: true)

        viewModel.replace(changed)

        #expect(viewModel.events == [events[0], changed, events[2]])
    }

    @Test func joinedListDropsAnEventTheUserLeft() async {
        let viewModel = makeEventListViewModel(scope: .joined, repository: makeRepository())
        await viewModel.load()

        viewModel.replace(events[0].updatingParticipation(count: 0, isJoined: false))

        #expect(viewModel.events == [events[1], events[2]])
    }

    @Test func replaceOfAnUnknownEventChangesNothing() async {
        let viewModel = makeEventListViewModel(repository: makeRepository())
        await viewModel.load()

        viewModel.replace(MockEventFixtures.make(now: .now, count: 5)[4])

        #expect(viewModel.events == events)
    }

    /// The list that applied the change is current; every other list must reload on its next appearance.
    @Test func aChangeMadeElsewhereMakesTheOtherListStale() async {
        let changes = EventChangeTracker()
        let exploreRepository = makeRepository()
        let mineRepository = makeRepository()
        let explore = makeEventListViewModel(scope: .upcoming, repository: exploreRepository, changes: changes)
        let mine = makeEventListViewModel(scope: .joined, repository: mineRepository, changes: changes)
        await explore.loadIfStale()
        await mine.loadIfStale()

        explore.replace(events[0].updatingParticipation(count: 1, isJoined: true))
        await explore.loadIfStale()
        await mine.loadIfStale()
        await mine.loadIfStale()

        #expect(exploreRepository.requestedScopes.count == 1)
        #expect(mineRepository.requestedScopes.count == 2)
    }

    /// A change that lands while a load is in flight may be missing from its answer, so that load is not current.
    @Test func changeDuringALoadLeavesTheListStale() async {
        let changes = EventChangeTracker()
        let repository = makeRepository()
        let viewModel = makeEventListViewModel(repository: repository, changes: changes)
        repository.holdsRequests = true

        let load = Task { await viewModel.load() }
        await settle(until: { repository.requestedScopes.count == 1 })
        changes.recordChange()
        repository.releaseRequests()
        await load.value
        await viewModel.loadIfStale()

        #expect(repository.requestedScopes.count == 2)
    }

    /// A sign-in that lands while a load is in flight: the answer was for the guest, so that load is not current.
    @Test func signInDuringALoadLeavesTheListStale() async {
        let identity = FakeIdentityProvider()
        let repository = makeRepository()
        let viewModel = makeEventListViewModel(repository: repository, identity: identity)
        repository.holdsRequests = true

        let load = Task { await viewModel.load() }
        await settle(until: { repository.requestedScopes.count == 1 })
        identity.currentUserID = TestFixtures.user.id
        repository.releaseRequests()
        await load.value
        await viewModel.loadIfStale()

        #expect(repository.requestedScopes.count == 2)
    }

    /// Explore stays on screen across a sign-in; its `isJoined` flags were answered for the guest and must be asked again.
    @Test(arguments: identityChanges)
    func aChangeOfIdentityMakesTheListStale(before: String?, after: String?) async {
        let identity = FakeIdentityProvider(currentUserID: before)
        let repository = makeRepository()
        let viewModel = makeEventListViewModel(repository: repository, identity: identity)
        await viewModel.loadIfStale()
        await viewModel.loadIfStale()
        #expect(repository.requestedScopes.count == 1)

        identity.currentUserID = after
        await viewModel.loadIfStale()
        await viewModel.loadIfStale()

        #expect(repository.requestedScopes.count == 2)
    }
}
