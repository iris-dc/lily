import Foundation
import Testing
@testable import lily

/// The tournament flow's walk and issue partition: one idea per page, with the hosting-group page conditional on the
/// opening exactly like the event flow's.
struct CreationStepsTournamentTests {
    private static let group = EventGroupRef(id: "group-1", name: "Mitte Kickers", visibility: .private, isDeleted: false)

    /// The slice-3 partition, pinned literally so a reshuffled switch cannot pass unnoticed; the type, format,
    /// hosting-group and who-may-join pages own no issue by design.
    private static let partition: [TournamentDraft.Issue: CreationStep.TournamentStep] = [
        .nameTooShort: .name, .nameTooLong: .name,
        .startsAtTooSoon: .schedule, .registrationClosesAfterStart: .schedule,
        .locationNameMissing: .place, .locationNameTooLong: .place, .coordinateMissing: .place, .placeNotChosen: .place,
        .teamSizeOutOfRange: .entries, .maxEntriesOutOfRange: .entries, .maxEntriesBelowEntries: .entries,
        .descriptionTooLong: .details
    ]

    private static func opening(groups: Bool = true,
                                lockedGroup: EventGroupRef? = nil,
                                hasEligibleGroups: Bool = true) -> CreationWizardPolicy.Opening {
        CreationWizardPolicy.opening(for: CreationSeed(kind: .tournament, lockedGroup: lockedGroup),
                                     flags: CreationWizardPolicy.Flags(groups: groups, tournaments: true),
                                     hasEligibleGroups: hasEligibleGroups)
    }

    @Test func theTournamentFlowWalksOneIdeaPerPage() {
        #expect(CreationSteps.steps(for: .tournament, opening: Self.opening()) ==
                    [.tournament(.name), .tournament(.type), .tournament(.format), .tournament(.schedule),
                     .tournament(.group), .tournament(.place), .tournament(.entries),
                     .tournament(.whoMayJoin), .tournament(.details)])
    }

    /// The hosting-group page exists exactly when the attempt may choose, like the event flow's: groups on, nothing
    /// locked and a group to host in, all read once at the opening so a late reload can never change the walk.
    @Test func theGroupPageNeedsGroupsOnNothingLockedAndAGroupToHostIn() {
        let withoutGroupStep: [CreationStep] = [.tournament(.name), .tournament(.type), .tournament(.format),
                                                .tournament(.schedule), .tournament(.place), .tournament(.entries),
                                                .tournament(.whoMayJoin), .tournament(.details)]
        #expect(CreationSteps.steps(for: .tournament, opening: Self.opening(groups: false)) == withoutGroupStep)
        #expect(CreationSteps.steps(for: .tournament, opening: Self.opening(lockedGroup: Self.group))
                    == withoutGroupStep)
        #expect(CreationSteps.steps(for: .tournament, opening: Self.opening(groups: false, lockedGroup: Self.group))
                    == withoutGroupStep)
        #expect(CreationSteps.steps(for: .tournament, opening: Self.opening(hasEligibleGroups: false))
                    == withoutGroupStep)
    }

    @Test func everyTournamentIssueCaseIsInThePinnedPartition() {
        #expect(TournamentDraft.Issue.allCases.count == Self.partition.count)
    }

    @Test(arguments: TournamentDraft.Issue.allCases)
    func everyTournamentIssueBelongsToExactlyThePlannedStep(issue: TournamentDraft.Issue) {
        #expect(CreationSteps.tournamentStep(owning: issue) == Self.partition[issue])
    }

    /// The single-choice type and format pages and the optional group and who-may-join choices carry no issues:
    /// nothing on them can refuse.
    @Test(arguments: TournamentDraft.Issue.allCases)
    func theChoicePagesOwnNoIssue(issue: TournamentDraft.Issue) {
        let owner = CreationSteps.tournamentStep(owning: issue)
        #expect(owner != .type && owner != .format && owner != .group && owner != .whoMayJoin)
    }

    @Test(arguments: CreationStep.TournamentStep.allCases)
    func nextIsBlockedExactlyByAnIssueTheStepOwns(step: CreationStep.TournamentStep) {
        #expect(CreationSteps.allowsNext(from: step, issues: []))
        for issue in TournamentDraft.Issue.allCases {
            let allowed = CreationSteps.allowsNext(from: step, issues: [issue])
            #expect(allowed == (CreationSteps.tournamentStep(owning: issue) != step))
        }
    }

    /// The partition is total, so "every page allows Next" is exactly the whole-draft rule the create button keeps.
    @Test func theFinalGateEqualsEveryStepAllowingNext() {
        let issueSets: [[TournamentDraft.Issue]] = [[], [.nameTooShort],
                                                    [.coordinateMissing, .maxEntriesBelowEntries],
                                                    TournamentDraft.Issue.allCases]
        for issues in issueSets {
            let everyStepAllows = CreationStep.TournamentStep.allCases.allSatisfy {
                CreationSteps.allowsNext(from: $0, issues: issues)
            }
            #expect(everyStepAllows == issues.isEmpty)
        }
    }
}
