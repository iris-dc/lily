import Foundation

/// The tournament screens' view models, over the tournament repository that came in with the group repositories and
/// the change counter `GroupDependencies` owns (the realtime controller bumps the same one, so every tournament list,
/// segment and detail reloads on a change made anywhere).
extension AppDependencies {
    var tournamentRepository: any TournamentRepository { groups.repositories.tournaments }
    var tournamentChanges: ChangeTracker { groups.tournamentChanges }

    /// A tab's list (`ShellLists`) passes the app's snapshot store; a group's segment keeps none (the default).
    func makeTournamentListViewModel(scope: TournamentScope,
                                     snapshots: any ListSnapshotStore = NoOpListSnapshotStore()) -> TournamentListViewModel {
        TournamentListViewModel(scope: scope,
                                repository: tournamentRepository,
                                identity: identity,
                                locationService: locationService,
                                changes: tournamentChanges,
                                errorCenter: errorCenter,
                                logger: logger,
                                snapshots: snapshots)
    }

    /// `onChange` receives the tournament as the backend answered it; the list behind the detail replaces its row.
    func makeTournamentDetailViewModel(for destination: TournamentDestination,
                                       onChange: @escaping @MainActor (Tournament) -> Void) -> TournamentDetailViewModel {
        TournamentDetailViewModel(destination: destination,
                                  repository: tournamentRepository,
                                  groupRepository: groupRepository,
                                  myGroups: myGroups,
                                  identity: identity,
                                  navigation: navigation,
                                  changes: tournamentChanges,
                                  reporter: groups.errorReporter,
                                  recorder: interactionRecorder,
                                  logger: logger,
                                  pushOptIn: pushCoordinator,
                                  onChange: onChange)
    }

    /// `onCreated` receives the detail as the backend stored it. A sheet opened from a group's Tournaments segment
    /// passes the group as `lockedGroup`, so the tournament is hosted there.
    func makeCreateTournamentViewModel(lockedGroup: EventGroupRef? = nil,
                                       onCreated: @escaping @MainActor (TournamentDetail) -> Void) -> CreateTournamentViewModel {
        CreateTournamentViewModel(repository: tournamentRepository,
                                  identity: identity,
                                  locationService: locationService,
                                  groups: myGroups,
                                  reporter: groups.errorReporter,
                                  logger: logger,
                                  pushOptIn: pushCoordinator,
                                  lockedGroup: lockedGroup,
                                  onCreated: onCreated)
    }

    func makeEditTournamentViewModel(for tournament: Tournament,
                                     onChange: @escaping @MainActor (TournamentDetail) -> Void) -> EditTournamentViewModel {
        EditTournamentViewModel(tournament: tournament,
                                repository: tournamentRepository,
                                reporter: groups.errorReporter,
                                logger: logger,
                                onChange: onChange)
    }
}
