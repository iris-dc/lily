import Foundation
@testable import lily

/// The creation wizard model over real create view models on fakes: one `CreateEventHarness` behind the event flow,
/// a group and a tournament view model over the same identity, store and error center, and one `SpyLogger` the
/// wizard's lines land in. `factoryLockedGroups` records the locked group each event or tournament factory call
/// carried, recording that the factory ran at all.
@MainActor
final class CreationWizardHarness {
    /// `nonisolated`: read as a default argument off the actor.
    nonisolated static let everythingOn = CreationWizardPolicy.Flags(groups: true, tournaments: true)

    let events: CreateEventHarness
    let logger: SpyLogger
    let tournamentRepository: FakeTournamentRepository
    let factoryLockedGroups: Recorded<EventGroupRef?>
    let groupViewModel: CreateGroupViewModel
    let tournamentViewModel: CreateTournamentViewModel
    let model: AppCreationWizardModel

    init(seed: CreationSeed = .empty,
         flags: CreationWizardPolicy.Flags = CreationWizardHarness.everythingOn,
         hasEligibleGroups: Bool = true,
         locationService: (any LocationService)? = nil,
         lockedGroup: EventGroupRef? = nil) {
        let events = CreateEventHarness(locationService: locationService, lockedGroup: lockedGroup)
        let logger = SpyLogger()
        let recorded = Recorded<EventGroupRef?>()
        let tournamentRepository = FakeTournamentRepository()
        let groupViewModel = CreateGroupViewModel(repository: events.groupRepository,
                                                  identity: events.identity,
                                                  store: events.groups,
                                                  locationService: locationService ?? MockLocationService(),
                                                  errorCenter: events.errorCenter,
                                                  logger: logger,
                                                  tryAgainDelay: .zero,
                                                  onCreated: { _ in })
        let tournamentViewModel = CreateTournamentViewModel(repository: tournamentRepository,
                                                            identity: events.identity,
                                                            locationService: locationService ?? MockLocationService(),
                                                            groups: events.groups,
                                                            errorCenter: events.errorCenter,
                                                            logger: logger,
                                                            now: { CreateEventHarness.now },
                                                            lockedGroup: lockedGroup,
                                                            tryAgainDelay: .zero,
                                                            onCreated: { _ in })
        self.events = events
        self.logger = logger
        self.tournamentRepository = tournamentRepository
        self.groupViewModel = groupViewModel
        self.tournamentViewModel = tournamentViewModel
        factoryLockedGroups = recorded
        let factories = CreationWizardFactories(
            event: { locked in
                recorded.record(locked)
                return events.viewModel
            },
            group: { groupViewModel },
            tournament: { locked in
                recorded.record(locked)
                return tournamentViewModel
            })
        let opening = CreationWizardPolicy.opening(for: seed, flags: flags, hasEligibleGroups: hasEligibleGroups)
        model = CreationWizardModel(opening: opening, factories: factories, logger: logger)
    }

    var viewModel: CreateEventViewModel { events.viewModel }
}
