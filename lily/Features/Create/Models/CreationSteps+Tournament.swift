import Foundation

nonisolated extension CreationSteps {
    /// The tournament pages this attempt walks; the hosting-group page exists exactly when the attempt may choose
    /// one (`offersGroupChoice(_:)`), decided at the opening like the event flow's.
    static func tournamentSteps(opening: CreationWizardPolicy.Opening) -> [CreationStep.TournamentStep] {
        CreationStep.TournamentStep.allCases.filter { $0 != .group || offersGroupChoice(opening) }
    }

    /// The tournament page that owns an issue: exhaustive, so a new issue case must pick its page before it
    /// compiles. The type, format, hosting-group and who-may-join pages own none by design: single and optional
    /// choices have nothing to refuse.
    static func tournamentStep(owning issue: TournamentDraft.Issue) -> CreationStep.TournamentStep {
        switch issue {
        case .nameTooShort, .nameTooLong:
            .name
        case .startsAtTooSoon, .registrationClosesAfterStart:
            .schedule
        case .locationNameMissing, .locationNameTooLong, .coordinateMissing:
            .place
        case .teamSizeOutOfRange, .maxEntriesOutOfRange, .maxEntriesBelowEntries:
            .entries
        case .descriptionTooLong:
            .details
        }
    }

    /// Next on a tournament page is enabled exactly when the page owns none of the live issues; the final page's
    /// create button keeps the whole-draft rule instead.
    static func allowsNext(from step: CreationStep.TournamentStep, issues: [TournamentDraft.Issue]) -> Bool {
        issues.allSatisfy { tournamentStep(owning: $0) != step }
    }
}
