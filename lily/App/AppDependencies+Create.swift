import Foundation

/// The app's one wizard shape: the three create view models the composition root wires in. Call sites that hold a
/// model (Explore, a group's detail) name it through this alias, never the generic spelling.
typealias AppCreationWizardModel = CreationWizardModel<CreateEventViewModel, CreateGroupViewModel, CreateTournamentViewModel>

/// The creation wizard over the composition root: the policy's opening for an entry point's seed, the kind
/// view-model factories and the logging facade. The only place the wizard meets concrete types.
extension AppDependencies {
    /// The `onCreated*` closures are the presenting screen's existing created-callbacks, unchanged per entry point; a
    /// group screen's seed carries the locked hosting group, which the event and tournament factories pass through.
    /// The eligible-groups fact is read here, once, from the store the shell loads at sign-in, so the walk never
    /// follows a reload. The wizard view dismisses itself once the created thing is handed on.
    func makeCreationWizardModel(
        seed: CreationSeed,
        onCreatedEvent: @escaping @MainActor (SportEvent) -> Void,
        onCreatedGroup: @escaping @MainActor (SportGroup) -> Void,
        onCreatedTournament: @escaping @MainActor (TournamentDetail) -> Void
    ) -> AppCreationWizardModel {
        // Strong captures on purpose: the root outlives every wizard and never holds one back, so there is no cycle.
        let factories = CreationWizardFactories(
            event: { self.makeCreateEventViewModel(onCreated: onCreatedEvent, lockedGroup: $0) },
            group: { self.makeCreateGroupViewModel(onCreated: onCreatedGroup) },
            tournament: { self.makeCreateTournamentViewModel(lockedGroup: $0, onCreated: onCreatedTournament) })
        let opening = CreationWizardPolicy.opening(for: seed,
                                                   flags: .current,
                                                   hasEligibleGroups: !myGroups.eligibleForEvents.isEmpty)
        return CreationWizardModel(opening: opening, factories: factories, logger: logger)
    }
}
