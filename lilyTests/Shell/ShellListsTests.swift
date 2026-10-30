import Foundation
import Testing
@testable import lily

/// Explore's lists are loaded ahead of the tab; Home's are Home's own.
@MainActor
struct ShellListsTests {
    private let events = FakeEventRepository()
    private let tournaments = FakeTournamentRepository()
    private let groups = FakeGroupRepository()
    private let identity = FakeIdentityProvider(currentUserID: TestFixtures.user.id)
    private let logger = SpyLogger()
    private let lists: ShellLists

    init() {
        let errorCenter = ErrorCenter(logger: logger)
        lists = ShellLists(homeEvents: makeEventListViewModel(scope: .joined, repository: events, identity: identity),
                           homeTournaments: Self.makeTournaments(scope: .mine,
                                                                 repository: tournaments,
                                                                 identity: identity,
                                                                 errorCenter: errorCenter,
                                                                 logger: logger),
                           exploreEvents: makeEventListViewModel(scope: .upcoming, repository: events, identity: identity),
                           discover: DiscoverGroupsViewModel(changes: ChangeTracker(),
                                                             repository: groups,
                                                             identity: identity,
                                                             locationService: MockLocationService(),
                                                             errorCenter: errorCenter,
                                                             recorder: SpyInteractionRecorder(),
                                                             logger: logger),
                           exploreTournaments: Self.makeTournaments(scope: .upcoming,
                                                                    repository: tournaments,
                                                                    identity: identity,
                                                                    errorCenter: errorCenter,
                                                                    logger: logger))
    }

    private static func makeTournaments(scope: TournamentScope,
                                        repository: FakeTournamentRepository,
                                        identity: FakeIdentityProvider,
                                        errorCenter: ErrorCenter,
                                        logger: SpyLogger) -> TournamentListViewModel {
        TournamentListViewModel(scope: scope,
                                repository: repository,
                                identity: identity,
                                locationService: MockLocationService(),
                                changes: ChangeTracker(),
                                errorCenter: errorCenter,
                                logger: logger)
    }

    @Test func loadsExploreAndNotHome() async {
        await lists.loadExploreIfStale()

        #expect(events.requestedScopes.contains(.upcoming) && !events.requestedScopes.contains(.joined))
        #expect(tournaments.requestedScopes.contains(.upcoming) == AppConfig.FeatureFlags.tournaments)
        #expect(!tournaments.requestedScopes.contains(.mine))
        #expect(groups.requestedScopes.isEmpty != AppConfig.FeatureFlags.groups)
        #expect(lists.exploreEvents.userLocation != nil)
    }

    /// Within the lists' TTL a later run (a return to the foreground) asks nothing.
    @Test func aSecondRunWithinTheTTLAsksNothing() async {
        await lists.loadExploreIfStale()
        let asked = (events.requestedScopes.count, tournaments.requestedScopes.count, groups.requestedScopes.count)

        await lists.loadExploreIfStale()

        #expect((events.requestedScopes.count, tournaments.requestedScopes.count, groups.requestedScopes.count) == asked)
    }

    /// Explore is for guests too.
    @Test func aGuestIsLoadedAsWell() async {
        identity.currentUserID = nil

        await lists.loadExploreIfStale()

        #expect(events.requestedScopes.contains(.upcoming))
    }

    /// The lists outlive the session, so its end empties every one and forgets its loads: the next caller's first load
    /// is theirs.
    @Test func theSessionEndingClearsEveryList() async {
        events.result = .success([.fixture(id: "e")])
        tournaments.result = .success([.fixture(id: "t")])
        groups.result = .success([.fixture(id: "g")])
        await lists.loadExploreIfStale()
        await lists.homeEvents.loadIfStale()
        await lists.homeTournaments.loadIfStale()
        #expect(!lists.exploreEvents.events.isEmpty && !lists.homeEvents.events.isEmpty)

        lists.sessionDidEnd()

        #expect(lists.exploreEvents.events.isEmpty && !lists.exploreEvents.hasLoaded)
        #expect(lists.homeEvents.events.isEmpty && !lists.homeEvents.hasLoaded)
        #expect(lists.homeTournaments.tournaments.isEmpty && !lists.homeTournaments.hasLoaded)
        #expect(lists.exploreTournaments.tournaments.isEmpty && !lists.exploreTournaments.hasLoaded)
        #expect(lists.discover.groups.isEmpty && !lists.discover.hasSearched)
    }
}
