import Foundation
import Testing
@testable import lily

/// How a game created on Explore reaches the list behind the sheet, and the lists beside it.
@MainActor
struct EventListAddTests {
    /// `nonisolated`: read by the stored property initialiser below.
    nonisolated private static let now = Date(timeIntervalSince1970: 1_800_000_000)
    nonisolated private static let secondsPerHour: TimeInterval = 3600

    /// Three loaded games, in start order (the fixtures are chronological).
    private let loaded = MockEventFixtures.make(now: Self.now, count: 3)

    private func makeRepository() -> FakeEventRepository {
        let repository = FakeEventRepository()
        repository.result = .success(loaded)
        return repository
    }

    /// A game the caller hosts, so they are in it, unless a test says otherwise.
    private func makeCreated(id: String = "created", startsAt: Date, isJoined: Bool = true) -> SportEvent {
        .fixture(id: id, startsAt: startsAt, hostUserId: TestFixtures.user.id, isJoined: isJoined)
    }

    /// A start halfway between two loaded games.
    private func midway(_ first: SportEvent, _ second: SportEvent) -> Date {
        first.startsAt.addingTimeInterval(second.startsAt.timeIntervalSince(first.startsAt) / 2)
    }

    /// Explore is in the backend's relevance order for the caller, so there is no slot to compute on device, and the
    /// caller's own new game belongs on top.
    @Test func addPutsTheCreatedEventFirstOnExplore() async {
        let viewModel = makeEventListViewModel(repository: makeRepository())
        await viewModel.load()
        let created = makeCreated(startsAt: loaded[2].startsAt.addingTimeInterval(Self.secondsPerHour))

        viewModel.add(created)

        #expect(viewModel.events == [created] + loaded)
    }

    /// My Events stays chronological, so a created game lands where a reload would put it.
    @Test func joinedListPlacesTheEarliestFirstAndTheLatestLast() async {
        let viewModel = makeEventListViewModel(scope: .joined, repository: makeRepository())
        await viewModel.load()
        let earliest = makeCreated(id: "earliest", startsAt: loaded[0].startsAt.addingTimeInterval(-Self.secondsPerHour))
        let latest = makeCreated(id: "latest", startsAt: loaded[2].startsAt.addingTimeInterval(Self.secondsPerHour))

        viewModel.add(latest)
        viewModel.add(earliest)

        #expect(viewModel.events.map(\.id) == ["earliest"] + loaded.map(\.id) + ["latest"])
    }

    /// The host is always in, so My Events takes a game created from Explore.
    @Test func joinedListTakesAGameTheUserIsIn() async {
        let viewModel = makeEventListViewModel(scope: .joined, repository: makeRepository())
        await viewModel.load()
        let created = makeCreated(startsAt: midway(loaded[0], loaded[1]))

        viewModel.add(created)

        #expect(viewModel.events == [loaded[0], created, loaded[1], loaded[2]])
    }

    @Test func joinedListIgnoresAGameTheUserIsNotIn() async {
        let viewModel = makeEventListViewModel(scope: .joined, repository: makeRepository())
        await viewModel.load()

        viewModel.add(makeCreated(startsAt: midway(loaded[0], loaded[1]), isJoined: false))

        #expect(viewModel.events == loaded)
    }

    @Test func addIsNotAppliedTwiceForTheSameEvent() async {
        let viewModel = makeEventListViewModel(repository: makeRepository())
        await viewModel.load()
        let created = makeCreated(startsAt: midway(loaded[0], loaded[1]))

        viewModel.add(created)
        viewModel.add(created)

        #expect(viewModel.events.count == loaded.count + 1)
        #expect(Set(viewModel.events.map(\.id)).count == viewModel.events.count)
    }

    /// The list that added the game is current; every other list reloads on its next appearance.
    @Test func addKeepsThisListCurrentAndMakesSiblingsStale() async {
        let changes = ChangeTracker()
        let exploreRepository = makeRepository()
        let mineRepository = makeRepository()
        let explore = makeEventListViewModel(scope: .upcoming, repository: exploreRepository, changes: changes)
        let mine = makeEventListViewModel(scope: .joined, repository: mineRepository, changes: changes)
        await explore.loadIfStale()
        await mine.loadIfStale()

        explore.add(makeCreated(startsAt: midway(loaded[0], loaded[1])))
        await explore.loadIfStale()
        await mine.loadIfStale()
        await mine.loadIfStale()

        #expect(exploreRepository.requestedScopes.count == 1)
        #expect(mineRepository.requestedScopes.count == 2)
    }

    @Test func addLogsTheInvalidation() async {
        let logger = SpyLogger()
        let viewModel = makeEventListViewModel(repository: makeRepository(), logger: logger)
        await viewModel.load()
        let created = makeCreated(startsAt: midway(loaded[0], loaded[1]))

        viewModel.add(created)

        let cacheLines = logger.messages(in: .cache, at: .debug)
        #expect(cacheLines.contains { $0.contains("Event \(created.id) added") && $0.contains("sibling lists invalidated") })
    }
}

/// A group's Events segment lists that group's games only, in start order.
@MainActor
struct EventListGroupAddTests {
    nonisolated private static let now = Date(timeIntervalSince1970: 1_800_000_000)
    nonisolated private static let secondsPerHour: TimeInterval = 3600
    private let kickers = EventGroupRef(id: "kickers", name: "Kreuzberg Kickers", visibility: .public, isDeleted: false)
    private let padel = EventGroupRef(id: "padel", name: "Sunday Padel Crew", visibility: .private, isDeleted: false)

    private func makeLoaded() -> [SportEvent] {
        (0..<3).map { index in
            SportEvent.fixture(id: "g\(index)", startsAt: Self.now.addingTimeInterval(Double(index) * 4 * Self.secondsPerHour))
                .hosted(in: kickers)
        }
    }

    @Test func groupScopeInsertsOnlyItsOwnGroupsGames() async {
        let loaded = makeLoaded()
        let repository = FakeEventRepository()
        repository.result = .success(loaded)
        let viewModel = makeEventListViewModel(scope: .group(id: kickers.id), repository: repository)
        await viewModel.load()
        let midway = Self.now.addingTimeInterval(6 * Self.secondsPerHour)
        let host = TestFixtures.user.id
        let ours = SportEvent.fixture(id: "ours", startsAt: midway, hostUserId: host, isJoined: true).hosted(in: kickers)
        let theirs = SportEvent.fixture(id: "theirs", startsAt: midway, hostUserId: host, isJoined: true).hosted(in: padel)
        let ungrouped = SportEvent.fixture(id: "solo", startsAt: midway, hostUserId: host, isJoined: true)

        viewModel.add(theirs)
        viewModel.add(ungrouped)
        viewModel.add(ours)

        #expect(viewModel.events.map(\.id) == ["g0", "g1", "ours", "g2"])
    }
}

private extension SportEvent {
    /// The same event stamped with a group, the way the backend answers a grouped game.
    func hosted(in group: EventGroupRef) -> SportEvent {
        SportEvent(id: id,
                   title: title,
                   type: type,
                   startsAt: startsAt,
                   location: location,
                   capacity: capacity,
                   participantCount: participantCount,
                   hostName: hostName,
                   hostUserId: hostUserId,
                   isJoined: isJoined,
                   group: group)
    }
}
