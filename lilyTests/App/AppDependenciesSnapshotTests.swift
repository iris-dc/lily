import Foundation
import Testing
@testable import lily

/// Where the tabs' lists keep their last answer, and the lists the root owns for the app's lifetime.
@MainActor
struct AppDependenciesSnapshotTests {
    private let logger = SpyLogger()
    private let directory = FileManager.default.temporaryDirectory.appending(path: "root-snapshots-\(UUID().uuidString)")

    /// A mock run stays in memory throughout and never starts from a real backend's leftovers.
    @Test func aMockRunKeepsNoSnapshots() {
        let store = AppDependencies.makeListSnapshotStore(arguments: [AppConfig.LaunchArguments.mockEvents],
                                                          startsFresh: false,
                                                          directory: directory,
                                                          logger: logger)
        #expect(store is NoOpListSnapshotStore)
        #expect(AppDependencies.makeMock().listSnapshots is NoOpListSnapshotStore)
    }

    @Test func aRunAgainstABackendKeepsThemOnDiskAndAFreshStartClearsThem() {
        defer { try? FileManager.default.removeItem(at: directory) }
        let key = ListSnapshotKey(list: "events-upcoming", userID: nil)
        let store = AppDependencies.makeListSnapshotStore(arguments: [], startsFresh: false, directory: directory, logger: logger)
        #expect(store is FileListSnapshotStore)
        store.save([SportEvent.fixture(id: "a", startsAt: Date(timeIntervalSince1970: 1_800_000_000))], for: key)
        #expect(store.load([SportEvent].self, for: key)?.count == 1)

        let fresh = AppDependencies.makeListSnapshotStore(arguments: [], startsFresh: true, directory: directory, logger: logger)

        #expect(fresh.load([SportEvent].self, for: key) == nil)
        #expect(!FileManager.default.fileExists(atPath: directory.path()))
    }

    /// The lists are built once, for the app's lifetime, with the carousels keeping a failure to the log.
    @Test func theRootOwnsOneSetOfTabLists() {
        let dependencies = AppDependencies.makeMock()

        let lists = dependencies.lists
        #expect(lists.exploreEvents === dependencies.lists.exploreEvents && lists.homeEvents !== lists.exploreEvents)
        #expect(!lists.discover.reportsSearchFailures && !lists.exploreTournaments.reportsFailures)
        #expect(lists.exploreTournaments.scope == .upcoming && lists.homeTournaments.scope == .mine)
    }

    /// The snapshot store and the tabs' lists are session observers: a sign-out empties the lists and then sweeps the
    /// snapshots, so nothing of the account is left for the next.
    @Test func theSessionEndingClearsTheListsAndTheSnapshots() async {
        let snapshots = InMemoryListSnapshotStore()
        let dependencies = makeDependencies(snapshots: snapshots, sessionStore: InMemorySessionStore())
        await dependencies.sessionController.signIn(with: .apple)
        await dependencies.lists.exploreEvents.loadIfStale()
        #expect(dependencies.sessionController.state.isSignedIn && !dependencies.lists.exploreEvents.events.isEmpty)
        #expect(snapshots.clearCount == 0 && !snapshots.storedFiles.isEmpty)

        await dependencies.sessionController.signOut()

        #expect(dependencies.lists.exploreEvents.events.isEmpty && !dependencies.lists.exploreEvents.hasLoaded)
        #expect(snapshots.clearCount == 1 && snapshots.storedFiles.isEmpty)
    }

    /// Mine reads the caller for its snapshot when it is built, so the identity is wired to the controller before the
    /// stores: a launch with a cached user shows their groups on the first frame.
    @Test func mineStartsFromTheCachedCallersSnapshotAtConstruction() {
        let snapshots = InMemoryListSnapshotStore()
        let held = [SportGroup.fixture(id: "held", role: .member)]
        snapshots.seed(held, for: ListSnapshotKey(list: "groups-mine", userID: TestFixtures.user.id))
        let sessionStore = InMemorySessionStore()
        sessionStore.stored = .signedIn(TestFixtures.session)

        let dependencies = makeDependencies(snapshots: snapshots, sessionStore: sessionStore)

        #expect(dependencies.myGroups.groups == held && !dependencies.myGroups.hasLoaded)
        #expect(dependencies.navigation.selectedTab == .home)
    }

    /// The mock root with a snapshot store and a session store of the test's own.
    private func makeDependencies(snapshots: any ListSnapshotStore, sessionStore: any SessionStore) -> AppDependencies {
        let mock = AppDependencies.makeMock()
        return AppDependencies(logger: logger,
                               sessionStore: sessionStore,
                               authService: MockAuthService(behavior: .succeed, delay: .zero, store: sessionStore),
                               eventRepository: mock.eventRepository,
                               profileRepository: mock.profileRepository,
                               feedbackRepository: mock.feedbackRepository,
                               interactionRecorder: NoOpInteractionRecorder(),
                               locationService: MockLocationService(),
                               groupRepositories: mock.groups.repositories,
                               pushRegistrar: MockPushRegistrar(logger: logger),
                               deviceRepository: MockDeviceRepository(identity: FakeIdentityProvider(), logger: logger),
                               listSnapshots: snapshots,
                               defaults: makeTestDefaults())
    }
}
