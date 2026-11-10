import Foundation

/// One entry on the wizard's navigation path: a step page the Next button pushes, or the map picker the place step
/// pushes. Steps nest per kind so a new kind's pages slot in as a sibling case with its own step enum.
nonisolated enum CreationStep: Hashable, Sendable {
    case event(EventStep)
    /// The map picker the event place step pushes: a path element because the wizard's stack is bound to the typed
    /// `[CreationStep]` path, which disables a link carrying any other value, and a stack rebuilt from the path on a
    /// re-host keeps the picker. Never in `steps(for:)`, so the step walk, the counter and `pop(to:)` ignore it.
    case eventMap

    /// The event flow's pages; `allCases` is the order walked.
    enum EventStep: CaseIterable, Hashable, Sendable {
        case basics
        case place
        case players
    }
}

/// The wizard's step lists and gating rules: which pages a kind walks, which page owns each validation issue, and
/// when Next may move forward. The per-kind issue partitions live in extension files (`CreationSteps+Event.swift`).
nonisolated enum CreationSteps {
    /// The ordered pages of a kind's flow. The group and tournament flows have no pages yet; a kind without pages
    /// must not be routed into the wizard.
    static func steps(for kind: CreationKind) -> [CreationStep] {
        switch kind {
        case .event: CreationStep.EventStep.allCases.map(CreationStep.event)
        case .group, .tournament: []
        }
    }
}
