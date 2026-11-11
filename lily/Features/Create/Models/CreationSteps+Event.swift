import Foundation

nonisolated extension CreationSteps {
    /// The event pages this attempt walks; the hosting-group page exists exactly when the attempt may choose one
    /// (`offersGroupChoice(_:)`).
    static func eventSteps(opening: CreationWizardPolicy.Opening) -> [CreationStep.EventStep] {
        CreationStep.EventStep.allCases.filter { $0 != .group || offersGroupChoice(opening) }
    }

    /// The event page that owns an issue: exhaustive, so a new issue case must pick its page before it compiles. The
    /// type and hosting-group pages own none by design: a single choice and an optional one have nothing to refuse.
    static func eventStep(owning issue: EventDraft.Issue) -> CreationStep.EventStep {
        switch issue {
        case .titleMissing, .titleTooLong:
            .name
        case .startsAtTooSoon:
            .when
        case .placeMissing, .locationNameTooLong:
            .place
        case .capacityOutOfRange, .capacityBelowParticipants:
            .players
        case .descriptionTooLong, .lookingForTooLong, .priceUnreadable, .priceOutOfRange:
            .details
        }
    }

    /// Next on an event page is enabled exactly when the page owns none of the live issues — the step's issue set
    /// and the draft's issues do not intersect. The final page's create button keeps the whole-draft rule instead
    /// (every issue empty, wherever it lives), so an issue that aged on an earlier page can never be submitted.
    static func allowsNext(from step: CreationStep.EventStep, issues: [EventDraft.Issue]) -> Bool {
        issues.allSatisfy { eventStep(owning: $0) != step }
    }
}
