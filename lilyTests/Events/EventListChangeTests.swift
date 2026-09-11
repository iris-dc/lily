import Foundation
import Testing
@testable import lily

/// How a participation change made on the detail screen reaches the lists behind it.
@MainActor
struct EventListChangeTests {
    private let events = MockEventFixtures.make(now: .now, count: 3)

    private func makeViewModel(scope: EventScope, changes: EventChangeTracker) -> (EventListViewModel, FakeEventRepository) {
        let repository = FakeEventRepository()
        repository.result = .success(events)
        let viewModel = EventListViewModel(scope: scope,
                                           repository: repository,
                                           locationService: MockLocationService(),
                                           changes: changes,
                                           errorCenter: ErrorCenter(logger: SpyLogger()),
                                           logger: SpyLogger())
        return (viewModel, repository)
    }

    @Test func replaceUpdatesTheEventInPlace() async {
        let (viewModel, _) = makeViewModel(scope: .upcoming, changes: EventChangeTracker())
        await viewModel.load()
        let changed = events[1].updatingParticipation(count: events[1].participantCount + 1, isJoined: true)

        viewModel.replace(changed)

        #expect(viewModel.events == [events[0], changed, events[2]])
    }

    @Test func joinedListDropsAnEventTheUserLeft() async {
        let (viewModel, _) = makeViewModel(scope: .joined, changes: EventChangeTracker())
        await viewModel.load()

        viewModel.replace(events[0].updatingParticipation(count: 0, isJoined: false))

        #expect(viewModel.events == [events[1], events[2]])
    }

    @Test func replaceOfAnUnknownEventChangesNothing() async {
        let (viewModel, _) = makeViewModel(scope: .upcoming, changes: EventChangeTracker())
        await viewModel.load()

        viewModel.replace(MockEventFixtures.make(now: .now, count: 5)[4])

        #expect(viewModel.events == events)
    }

    /// The list that applied the change is current; every other list must reload on its next appearance.
    @Test func aChangeMadeElsewhereMakesTheOtherListStale() async {
        let changes = EventChangeTracker()
        let (explore, exploreRepository) = makeViewModel(scope: .upcoming, changes: changes)
        let (mine, mineRepository) = makeViewModel(scope: .joined, changes: changes)
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
        let (viewModel, repository) = makeViewModel(scope: .upcoming, changes: changes)
        repository.holdsRequests = true

        let load = Task { await viewModel.load() }
        for _ in 0..<10 { await Task.yield() }
        changes.recordChange()
        repository.releaseRequests()
        await load.value
        await viewModel.loadIfStale()

        #expect(repository.requestedScopes.count == 2)
    }
}
