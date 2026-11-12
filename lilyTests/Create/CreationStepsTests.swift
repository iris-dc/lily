import Foundation
import Testing
@testable import lily

struct CreationStepsTests {
    private typealias Flags = CreationWizardPolicy.Flags
    private static let group = EventGroupRef(id: "group-1", name: "Mitte Kickers", visibility: .private, isDeleted: false)

    /// The second design round's partition, pinned literally so a reshuffled switch cannot pass unnoticed; the type
    /// and hosting-group pages own no issue by design.
    private static let partition: [EventDraft.Issue: CreationStep.EventStep] = [
        .titleMissing: .name, .titleTooLong: .name,
        .startsAtTooSoon: .when, .endsBeforeStart: .when,
        .placeMissing: .place, .placeNotChosen: .place, .locationNameTooLong: .place,
        .capacityOutOfRange: .players, .capacityBelowParticipants: .players,
        .descriptionTooLong: .details, .lookingForTooLong: .details,
        .priceUnreadable: .details, .priceOutOfRange: .details
    ]

    private static func opening(groups: Bool,
                                lockedGroup: EventGroupRef? = nil,
                                hasEligibleGroups: Bool = true) -> CreationWizardPolicy.Opening {
        CreationWizardPolicy.opening(for: CreationSeed(kind: .event, lockedGroup: lockedGroup),
                                     flags: Flags(groups: groups, tournaments: false),
                                     hasEligibleGroups: hasEligibleGroups)
    }

    @Test func theEventFlowWalksOneIdeaPerPage() {
        #expect(CreationSteps.steps(for: .event, opening: Self.opening(groups: true)) ==
                    [.event(.name), .event(.type), .event(.when), .event(.group),
                     .event(.place), .event(.players), .event(.details)])
    }

    /// The hosting-group page exists exactly when the attempt may choose: groups on, nothing locked and a group to
    /// host in — the plan's "skipped when locked, groups off, or none". The list is decided by the opening alone,
    /// so a late eligible-groups reload can never change the walk.
    @Test func theGroupPageNeedsGroupsOnNothingLockedAndAGroupToHostIn() {
        let withoutGroupStep: [CreationStep] = [.event(.name), .event(.type), .event(.when),
                                                .event(.place), .event(.players), .event(.details)]
        #expect(CreationSteps.steps(for: .event, opening: Self.opening(groups: false)) == withoutGroupStep)
        #expect(CreationSteps.steps(for: .event, opening: Self.opening(groups: true, lockedGroup: Self.group))
                    == withoutGroupStep)
        #expect(CreationSteps.steps(for: .event, opening: Self.opening(groups: false, lockedGroup: Self.group))
                    == withoutGroupStep)
        #expect(CreationSteps.steps(for: .event, opening: Self.opening(groups: true, hasEligibleGroups: false))
                    == withoutGroupStep)
    }

    @Test func everyEventIssueCaseIsInThePinnedPartition() {
        #expect(EventDraft.Issue.allCases.count == Self.partition.count)
    }

    @Test(arguments: EventDraft.Issue.allCases)
    func everyEventIssueBelongsToExactlyThePlannedStep(issue: EventDraft.Issue) {
        #expect(CreationSteps.eventStep(owning: issue) == Self.partition[issue])
    }

    /// The single-choice type page and the optional hosting-group page carry no issues: nothing on them can refuse.
    @Test(arguments: EventDraft.Issue.allCases)
    func theChoicePagesOwnNoIssue(issue: EventDraft.Issue) {
        let owner = CreationSteps.eventStep(owning: issue)
        #expect(owner != .type && owner != .group)
    }

    @Test(arguments: CreationStep.EventStep.allCases)
    func nextIsBlockedExactlyByAnIssueTheStepOwns(step: CreationStep.EventStep) {
        #expect(CreationSteps.allowsNext(from: step, issues: []))
        for issue in EventDraft.Issue.allCases {
            let allowed = CreationSteps.allowsNext(from: step, issues: [issue])
            #expect(allowed == (CreationSteps.eventStep(owning: issue) != step))
        }
    }

    /// The partition is total, so "every page allows Next" is exactly the whole-draft rule the create button keeps.
    @Test func theFinalGateEqualsEveryStepAllowingNext() {
        let issueSets: [[EventDraft.Issue]] = [[], [.titleMissing], [.placeMissing, .priceUnreadable],
                                               EventDraft.Issue.allCases]
        for issues in issueSets {
            let everyStepAllows = CreationStep.EventStep.allCases.allSatisfy {
                CreationSteps.allowsNext(from: $0, issues: issues)
            }
            #expect(everyStepAllows == issues.isEmpty)
        }
    }

    @Test func aRealDraftsIssuesGateTheOwningPageAndTheFinalGate() {
        let now = Date.now
        var draft = EventDraft.fixture(now: now)
        let valid = draft.issues(now: now)
        #expect(valid.isEmpty)
        #expect(CreationStep.EventStep.allCases.allSatisfy { CreationSteps.allowsNext(from: $0, issues: valid) })
        draft.title = " "
        let blocked = draft.issues(now: now)
        #expect(!CreationSteps.allowsNext(from: .name, issues: blocked))
        #expect(CreationStep.EventStep.allCases.filter { $0 != .name }
                    .allSatisfy { CreationSteps.allowsNext(from: $0, issues: blocked) })
    }
}
