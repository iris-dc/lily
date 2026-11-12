import Foundation

nonisolated extension CreationSteps {
    /// The group pages every attempt walks: the flow has no conditional page, and Visibility precedes Place by the
    /// recorded supersession — the place issues stay conditional on the choice, and the visibility caption carries
    /// the rule.
    static func groupSteps() -> [CreationStep.GroupStep] {
        CreationStep.GroupStep.allCases
    }

    /// The group page that owns an issue: exhaustive, so a new issue case must pick its page before it compiles. The
    /// type, visibility and permissions pages own none by design: a choice that always holds a value has nothing to
    /// refuse, and the final page's button is gated by the whole-draft rule instead.
    static func groupStep(owning issue: GroupDraft.Issue) -> CreationStep.GroupStep {
        switch issue {
        case .nameTooShort, .nameTooLong:
            .name
        case .descriptionTooLong:
            .description
        case .locationNameMissing, .locationNameTooLong, .coordinateMissing, .placeNotChosen:
            .place
        }
    }

    /// Next on a group page is enabled exactly when the page owns none of the live issues; the final page's create
    /// button keeps the whole-draft rule instead.
    static func allowsNext(from step: CreationStep.GroupStep, issues: [GroupDraft.Issue]) -> Bool {
        issues.allSatisfy { groupStep(owning: $0) != step }
    }
}
