import Foundation

/// One entry on the wizard's navigation path: a step page the Next button pushes, or the map picker the place step
/// pushes. Steps nest per kind so a new kind's pages slot in as a sibling case with its own step enum.
nonisolated enum CreationStep: Hashable, Sendable {
    case event(EventStep)
    /// The map picker the event place step pushes: a path element because the wizard's stack is bound to the typed
    /// `[CreationStep]` path, which disables a link carrying any other value, and a stack rebuilt from the path on a
    /// re-host keeps the picker. Never in `steps(for:opening:)`, so the step walk, the progress mark and `pop(to:)`
    /// ignore it.
    case eventMap

    /// The event flow's pages, one idea each; `allCases` is the order walked,
    /// with `group` present only when the attempt may choose one (`CreationSteps.eventSteps(opening:)`).
    enum EventStep: CaseIterable, Hashable, Sendable {
        case name
        case type
        case when
        case group
        case place
        case players
        case details
    }
}

/// The wizard's step lists and gating rules: which pages a kind walks for an opening, which page owns each validation
/// issue, and when Next may move forward. The per-kind issue partitions live in extension files
/// (`CreationSteps+Event.swift`).
nonisolated enum CreationSteps {
    /// The ordered pages of a kind's flow under the opening (flags, seed, eligible groups), deterministic per
    /// attempt. The group and tournament flows have no pages yet; a kind without pages must not be routed into the
    /// wizard.
    static func steps(for kind: CreationKind, opening: CreationWizardPolicy.Opening) -> [CreationStep] {
        switch kind {
        case .event: eventSteps(opening: opening).map(CreationStep.event)
        case .group, .tournament: []
        }
    }
}
