import Foundation

/// The creation wizard over the composition root: the policy's opening for an entry point's seed, the kind
/// view-model factories and the logging facade. The only place the wizard meets concrete types.
extension AppDependencies {
    /// `onCreatedEvent` is the presenting screen's existing created-callback, unchanged per entry point; a group
    /// screen's seed carries the locked hosting group, which the event factory passes through. The wizard view
    /// dismisses itself once the created event is handed on.
    func makeCreationWizardModel(
        seed: CreationSeed,
        onCreatedEvent: @escaping @MainActor (SportEvent) -> Void
    ) -> CreationWizardModel<CreateEventViewModel> {
        // A strong capture on purpose: the root outlives every wizard and never holds one back, so there is no cycle.
        let factories = CreationWizardFactories(event: { lockedGroup in
            self.makeCreateEventViewModel(onCreated: onCreatedEvent, lockedGroup: lockedGroup)
        })
        return CreationWizardModel(opening: CreationWizardPolicy.opening(for: seed, flags: .current),
                                   factories: factories,
                                   logger: logger)
    }
}
