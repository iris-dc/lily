import Foundation

/// What the creation wizard makes, carried in by the entry point's seed (the "+" menu, a keyboard shortcut, a group
/// screen's buttons). Declaration order is the "+" menu's order; `CreationWizardPolicy` filters it by the feature flags.
nonisolated enum CreationKind: CaseIterable, Hashable, Sendable {
    case event
    case group
    case tournament

    /// The kind a keyboard shortcut's parked `CreateIntent` asks the wizard for.
    init(_ intent: CreateIntent) {
        switch intent {
        case .game: self = .event
        case .group: self = .group
        case .tournament: self = .tournament
        }
    }
}
