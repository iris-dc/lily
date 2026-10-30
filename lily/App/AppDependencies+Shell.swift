import Foundation

extension AppDependencies {
    /// The shell's restore and per-user sync over the stores and coordinators built here; `AppRootView` only ties it
    /// to the scene phase and the session.
    func makeShellSync() -> ShellSync {
        ShellSync(session: sessionController,
                  navigation: navigation,
                  me: me,
                  realtime: realtime,
                  myGroups: myGroups,
                  inbox: inbox,
                  blocks: blocks,
                  push: pushCoordinator,
                  lists: lists)
    }

    /// The Home and Explore lists over the app's snapshot store. The carousels' view models keep a failure to the log:
    /// the events list on Explore reports its own, and a second popup would only repeat it.
    func makeShellLists() -> ShellLists {
        let discover = makeDiscoverGroupsViewModel(snapshots: listSnapshots)
        discover.reportsSearchFailures = false
        let exploreTournaments = makeTournamentListViewModel(scope: .upcoming, snapshots: listSnapshots)
        exploreTournaments.reportsFailures = false
        return ShellLists(homeEvents: makeEventListViewModel(scope: .joined, snapshots: listSnapshots),
                          homeTournaments: makeTournamentListViewModel(scope: .mine, snapshots: listSnapshots),
                          exploreEvents: makeEventListViewModel(scope: .upcoming, snapshots: listSnapshots),
                          discover: discover,
                          exploreTournaments: exploreTournaments)
    }

    /// Where the tabs' lists keep their last answer: files under `Caches/` for a run against a backend, cleared on a
    /// fresh start (`-reset-session`, decided and logged once by `makeDefault`) like the session and the choices;
    /// nothing for a mock run (`-mock-events`), which stays in memory throughout and must never start from a real
    /// backend's leftovers.
    static func makeListSnapshotStore(arguments: [String],
                                      startsFresh: Bool,
                                      directory: URL = FileListSnapshotStore.defaultDirectory,
                                      logger: any Logging) -> any ListSnapshotStore {
        guard !arguments.contains(AppConfig.LaunchArguments.mockEvents) else { return NoOpListSnapshotStore() }
        let store = FileListSnapshotStore(directory: directory, logger: logger)
        if startsFresh { store.clear() }
        return store
    }
}
