import Foundation
import Testing
@testable import lily

/// The group flow's walk and issue partition: one idea per page, Visibility before Place (the recorded supersession),
/// and the place issues conditional on the visibility choice exactly as `GroupDraft` computes them.
struct CreationStepsGroupTests {
    /// The slice-3 partition, pinned literally so a reshuffled switch cannot pass unnoticed; the type, visibility and
    /// permissions pages own no issue by design.
    private static let partition: [GroupDraft.Issue: CreationStep.GroupStep] = [
        .nameTooShort: .name, .nameTooLong: .name,
        .descriptionTooLong: .description,
        .locationNameMissing: .place, .locationNameTooLong: .place, .coordinateMissing: .place
    ]

    private static let opening = CreationWizardPolicy.opening(
        for: CreationSeed(kind: .group),
        flags: CreationWizardPolicy.Flags(groups: true, tournaments: true),
        hasEligibleGroups: true)

    @Test func theGroupFlowWalksOneIdeaPerPageWithVisibilityBeforePlace() {
        #expect(CreationSteps.steps(for: .group, opening: Self.opening) ==
                    [.group(.name), .group(.description), .group(.type), .group(.visibility),
                     .group(.place), .group(.permissions)])
    }

    @Test func everyGroupIssueCaseIsInThePinnedPartition() {
        #expect(GroupDraft.Issue.allCases.count == Self.partition.count)
    }

    @Test(arguments: GroupDraft.Issue.allCases)
    func everyGroupIssueBelongsToExactlyThePlannedStep(issue: GroupDraft.Issue) {
        #expect(CreationSteps.groupStep(owning: issue) == Self.partition[issue])
    }

    /// The single-choice type and visibility pages and the toggles-only permissions page carry no issues: nothing on
    /// them can refuse.
    @Test(arguments: GroupDraft.Issue.allCases)
    func theChoicePagesOwnNoIssue(issue: GroupDraft.Issue) {
        let owner = CreationSteps.groupStep(owning: issue)
        #expect(owner != .type && owner != .visibility && owner != .permissions)
    }

    @Test(arguments: CreationStep.GroupStep.allCases)
    func nextIsBlockedExactlyByAnIssueTheStepOwns(step: CreationStep.GroupStep) {
        #expect(CreationSteps.allowsNext(from: step, issues: []))
        for issue in GroupDraft.Issue.allCases {
            let allowed = CreationSteps.allowsNext(from: step, issues: [issue])
            #expect(allowed == (CreationSteps.groupStep(owning: issue) != step))
        }
    }

    /// The partition is total, so "every page allows Next" is exactly the whole-draft rule the create button keeps.
    @Test func theFinalGateEqualsEveryStepAllowingNext() {
        let issueSets: [[GroupDraft.Issue]] = [[], [.nameTooShort], [.locationNameMissing, .descriptionTooLong],
                                               GroupDraft.Issue.allCases]
        for issues in issueSets {
            let everyStepAllows = CreationStep.GroupStep.allCases.allSatisfy {
                CreationSteps.allowsNext(from: $0, issues: issues)
            }
            #expect(everyStepAllows == issues.isEmpty)
        }
    }

    /// A public group must name its place, a private one may skip it: the Place page gates on the choice the
    /// Visibility page made before it, exactly as the draft computes its issues.
    @Test func thePlaceGateFollowsTheVisibilityChoice() {
        var draft = GroupDraft()
        draft.name = "Kreuzberg Kickers"
        #expect(!CreationSteps.allowsNext(from: .place, issues: draft.issues))

        draft.visibility = .private
        #expect(CreationSteps.allowsNext(from: .place, issues: draft.issues))
        #expect(CreationSteps.allowsNext(from: .name, issues: draft.issues))
    }
}
