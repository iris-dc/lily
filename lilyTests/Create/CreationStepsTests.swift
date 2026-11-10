import Foundation
import Testing
@testable import lily

struct CreationStepsTests {
    /// The plan's partition, pinned literally so a reshuffled switch cannot pass unnoticed.
    private static let partition: [EventDraft.Issue: CreationStep.EventStep] = [
        .titleMissing: .basics, .titleTooLong: .basics, .startsAtTooSoon: .basics,
        .placeMissing: .place, .locationNameTooLong: .place,
        .capacityOutOfRange: .players, .capacityBelowParticipants: .players, .descriptionTooLong: .players,
        .lookingForTooLong: .players, .priceUnreadable: .players, .priceOutOfRange: .players
    ]

    @Test func theEventFlowWalksBasicsPlaceThenPlayers() {
        #expect(CreationSteps.steps(for: .event) == [.event(.basics), .event(.place), .event(.players)])
    }

    @Test func kindsWhosePagesHaveNotLandedHaveNoSteps() {
        #expect(CreationSteps.steps(for: .group).isEmpty)
        #expect(CreationSteps.steps(for: .tournament).isEmpty)
    }

    @Test func everyEventIssueCaseIsInThePinnedPartition() {
        #expect(EventDraft.Issue.allCases.count == Self.partition.count)
    }

    @Test(arguments: EventDraft.Issue.allCases)
    func everyEventIssueBelongsToExactlyThePlannedStep(issue: EventDraft.Issue) {
        #expect(CreationSteps.eventStep(owning: issue) == Self.partition[issue])
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
        #expect(!CreationSteps.allowsNext(from: .basics, issues: blocked))
        #expect(CreationSteps.allowsNext(from: .place, issues: blocked))
        #expect(CreationSteps.allowsNext(from: .players, issues: blocked))
    }
}
