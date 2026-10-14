import Foundation
import Testing
@testable import lily

/// How a participation change made on the detail screen, or a change of caller, reaches the lists behind it.
@MainActor
struct EventListChangeTests {
    nonisolated private static let base = Date(timeIntervalSince1970: 1_800_000_000)
    nonisolated private static let secondsPerHour: TimeInterval = 3600
    private let events = MockEventFixtures.make(now: .now, count: 3)
    private let kickers = EventGroupRef(id: "kickers", name: "Kreuzberg Kickers", visibility: .public, isDeleted: false)

    /// A guest signing in, and a user signing out: `isJoined` is the server's answer for the caller, so both stale.
    /// `nonisolated`: `@Test(arguments:)` reads it off the main actor.
    nonisolated private static let identityChanges: [(before: String?, after: String?)] = [(nil, "u-1"), ("u-1", nil)]

    private func makeRepository() -> FakeEventRepository {
        let repository = FakeEventRepository()
        repository.result = .success(events)
        return repository
    }

    /// Games "a", "b" and "c", an hour apart from `base`, all joined by the caller.
    private func joinedGames(in group: EventGroupRef? = nil) -> [SportEvent] {
        ["a", "b", "c"].enumerated().map { index, id in
            SportEvent.fixture(id: id,
                               startsAt: Self.base.addingTimeInterval(Double(index) * Self.secondsPerHour),
                               isJoined: true,
                               group: group)
        }
    }

    /// A list of `scope` that has loaded `loaded`, through `repository` when a test needs to count its requests.
    private func makeLoadedList(scope: EventScope,
                                loaded: [SportEvent],
                                repository: FakeEventRepository? = nil) async -> EventListViewModel {
        let repository = repository ?? FakeEventRepository()
        repository.result = .success(loaded)
        let viewModel = makeEventListViewModel(scope: scope, repository: repository)
        await viewModel.load()
        return viewModel
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

    /// Home and a group's Events are in start order; a host who moves their game must not leave the card where it was.
    @Test func replaceMovesAGameWhoseStartChangedOnAListInStartOrder() async {
        let viewModel = makeEventListViewModel(scope: .joined, repository: makeRepository())
        await viewModel.load()
        let hosted = events[0].updatingParticipation(count: events[0].participantCount, isJoined: true)
        var draft = EventDraft(editing: hosted)
        draft.startsAt = events[2].startsAt.addingTimeInterval(3600)
        let moved = hosted.updating(with: draft)

        viewModel.replace(moved)

        #expect(viewModel.events == [events[1], events[2], moved])
    }

    /// Explore is in the backend's relevance order, which a start change does not disturb.
    @Test func replaceKeepsThePlaceOnExploreWhateverTheStart() async {
        let viewModel = makeEventListViewModel(repository: makeRepository())
        await viewModel.load()
        var draft = EventDraft(editing: events[0])
        draft.startsAt = events[2].startsAt.addingTimeInterval(3600)
        let moved = events[0].updating(with: draft)

        viewModel.replace(moved)

        #expect(viewModel.events == [moved, events[1], events[2]])
    }

    /// Explore's relevance order cannot be guessed on device, so it never takes a game it does not hold.
    @Test func replaceOfAnUnknownEventChangesNothing() async {
        let viewModel = makeEventListViewModel(repository: makeRepository())
        await viewModel.load()

        viewModel.replace(MockEventFixtures.make(now: .now, count: 5)[4])

        #expect(viewModel.events == events)
    }

    /// A group's Events are in start order too; a host who moves their game there must not leave the card where it was.
    @Test func replaceOnAGroupListReInsertsByStart() async {
        let games = joinedGames(in: kickers)
        let viewModel = await makeLoadedList(scope: .group(id: kickers.id), loaded: games)
        var draft = EventDraft(editing: games[0])
        draft.startsAt = Self.base.addingTimeInterval(3 * Self.secondsPerHour)

        viewModel.replace(games[0].updating(with: draft))

        #expect(viewModel.events.map(\.id) == ["b", "c", "a"])
    }

    /// Unlike Home, a group's list is the group's games whoever is in them: one the user left stays, as left.
    @Test func replaceOnAGroupListKeepsAGameTheUserLeft() async {
        let games = joinedGames(in: kickers)
        let viewModel = await makeLoadedList(scope: .group(id: kickers.id), loaded: games)

        viewModel.replace(games[0].updatingParticipation(count: 0, isJoined: false))

        #expect(viewModel.events.map(\.id) == ["a", "b", "c"])
        #expect(viewModel.events[0].isJoined == false)
    }

    /// A join made on a detail pushed from a group's segment on the Home stack answers to Home's list, which does not
    /// hold the game yet: it takes it by start at once and is current for it, so no reload follows.
    @Test func replaceInsertsAGameTheUserJustJoinedIntoHome() async {
        let repository = FakeEventRepository()
        let games = joinedGames()
        let viewModel = await makeLoadedList(scope: .joined, loaded: [games[0], games[2]], repository: repository)

        viewModel.replace(games[1])
        await viewModel.loadIfStale()

        #expect(viewModel.events.map(\.id) == ["a", "b", "c"])
        #expect(repository.requestedScopes.count == 1)
    }

    /// Home lists the caller's own games only; a change to one they are not in is none of its business.
    @Test func replaceOfAGameTheUserIsNotInLeavesHomeAlone() async {
        let games = joinedGames()
        let viewModel = await makeLoadedList(scope: .joined, loaded: games)

        viewModel.replace(SportEvent.fixture(id: "d", startsAt: Self.base, isJoined: false))

        #expect(viewModel.events == games)
    }

    /// The list that applied the change is current; every other list must reload on its next appearance.
    @Test func aChangeMadeElsewhereMakesTheOtherListStale() async {
        let changes = ChangeTracker()
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

    /// A join applied while a refresh was out may be missing from its answer, so the refresh asks once more on its own
    /// instead of showing that answer until the next appearance.
    @Test func aRefreshInFlightReloadsOnceWhenAChangeLandedMeanwhile() async {
        let repository = makeRepository()
        let viewModel = makeEventListViewModel(repository: repository)
        repository.holdsRequests = true

        let load = Task { await viewModel.load() }
        await settle(until: { repository.requestedScopes.count == 1 })
        viewModel.replace(events[0].updatingParticipation(count: 1, isJoined: true))
        repository.releaseRequests()
        await load.value
        #expect(repository.requestedScopes.count == 2)
        #expect(!viewModel.isLoading)

        await viewModel.loadIfStale()
        #expect(repository.requestedScopes.count == 2)
    }

    /// A sign-in that lands while a refresh is out: the answer was for the guest, so the refresh asks once more as the
    /// user, and is current then.
    @Test func aSignInDuringARefreshReloadsOnceWhenItAnswers() async {
        let identity = FakeIdentityProvider()
        let repository = makeRepository()
        let viewModel = makeEventListViewModel(repository: repository, identity: identity)
        repository.holdsRequests = true

        let load = Task { await viewModel.load() }
        await settle(until: { repository.requestedScopes.count == 1 })
        identity.currentUserID = TestFixtures.user.id
        repository.releaseRequests()
        await load.value
        #expect(repository.requestedScopes.count == 2)
        #expect(!viewModel.isLoading)

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
