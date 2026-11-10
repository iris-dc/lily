import Foundation

nonisolated extension CreationSteps {
    /// The event page that owns an issue: exhaustive, so a new issue case must pick its page before it compiles.
    static func eventStep(owning issue: EventDraft.Issue) -> CreationStep.EventStep {
        switch issue {
        case .titleMissing, .titleTooLong, .startsAtTooSoon:
            .basics
        case .placeMissing, .locationNameTooLong:
            .place
        case .capacityOutOfRange, .capacityBelowParticipants, .descriptionTooLong, .lookingForTooLong,
             .priceUnreadable, .priceOutOfRange:
            .players
        }
    }

    /// Next on an event page is enabled exactly when the page owns none of the live issues — the step's issue set
    /// and the draft's issues do not intersect. The final page's create button keeps the whole-draft rule instead
    /// (every issue empty, wherever it lives), so an issue that aged on an earlier page can never be submitted.
    static func allowsNext(from step: CreationStep.EventStep, issues: [EventDraft.Issue]) -> Bool {
        issues.allSatisfy { eventStep(owning: $0) != step }
    }
}
