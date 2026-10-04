import Foundation

/// The tournaments feature's collaborators, held as one value so `AppDependencies` gains a single stored property: the
/// repository, and the change counter every tournament list reloads on (`GroupDependencies` owns it, so the realtime
/// controller bumps the same one).
struct TournamentDependencies {
    let repository: any TournamentRepository
    /// Counts tournament changes made anywhere, as `eventChanges` does for events.
    let tournamentChanges: ChangeTracker
}

extension AppDependencies {
    var tournamentRepository: any TournamentRepository { tournaments.repository }
    var tournamentChanges: ChangeTracker { tournaments.tournamentChanges }

    func makeTournamentListViewModel(scope: TournamentScope) -> TournamentListViewModel {
        TournamentListViewModel(scope: scope,
                                repository: tournamentRepository,
                                identity: identity,
                                locationService: locationService,
                                changes: tournamentChanges,
                                errorCenter: errorCenter,
                                logger: logger)
    }

    /// `onChange` receives the tournament as the backend answered it; the list behind the detail replaces its row.
    func makeTournamentDetailViewModel(for destination: TournamentDestination,
                                       onChange: @escaping @MainActor (Tournament) -> Void) -> TournamentDetailViewModel {
        TournamentDetailViewModel(destination: destination,
                                  repository: tournamentRepository,
                                  groupRepository: groupRepository,
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
