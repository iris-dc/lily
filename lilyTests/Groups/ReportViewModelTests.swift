import Foundation
import Testing
@testable import lily

/// The report sheet's model: nothing goes out without a reason, a send answers the thanks state, a failure the popup.
@MainActor
struct ReportViewModelTests {
    private let harness = GroupHarness()
    private let moderation = FakeModerationRepository()

    private func makeViewModel() -> ReportViewModel {
        ReportViewModel(target: .tournament(id: "t1"),
                        title: AppBranding.Tournaments.report,
                        repository: moderation,
                        reporter: harness.reporter,
                        logger: harness.logger)
    }

    @Test func aReasonIsNeededAndTheCommentIsTrimmedIntoThePayload() async {
        let viewModel = makeViewModel()
        #expect(!viewModel.canSubmit && viewModel.title == "Report tournament")

        await viewModel.submit()
        #expect(moderation.reports.isEmpty && !viewModel.isSubmitted)

        viewModel.reason = .harassment
        viewModel.comment = "  Fixed results  "
        #expect(viewModel.canSubmit)
        await viewModel.submit()

        let report = moderation.reports.first
        #expect(report?.targetType == .tournament && report?.targetId == "t1" && report?.groupId == "t1")
        #expect(report?.reason == .harassment && report?.comment == "Fixed results")
        #expect(viewModel.isSubmitted && !viewModel.isSubmitting && harness.presentedError == nil)
        #expect(harness.tournamentLogs(.info).contains { $0.hasPrefix("Report ") && $0.hasSuffix(" filed on tournament t1") })
        #expect(harness.logs().isEmpty, "a tournament's report is logged under the tournaments")
    }

    @Test func theLogCategoryFollowsTheTarget() {
        #expect(ReportTarget.tournament(id: "t").logCategory == .tournaments)
        #expect(ReportTarget.group(id: "g").logCategory == .groups && ReportTarget.user(id: "u").logCategory == .groups)
        #expect(ReportTarget.message(id: "m", groupID: "g").logCategory == .groups)
        #expect(InviteTarget.tournament(id: "t").logCategory == .tournaments)
        #expect(InviteTarget.group(id: "g").logCategory == .groups)
    }

    @Test func aCommentOverTheLimitHoldsTheSend() {
        let viewModel = makeViewModel()
        viewModel.reason = .spam
        viewModel.comment = String(repeating: "x", count: AppConfig.Moderation.commentMaxLength + 1)
        #expect(!viewModel.canSubmit)
        viewModel.comment = String(repeating: "x", count: AppConfig.Moderation.commentMaxLength)
        #expect(viewModel.canSubmit)
    }

    @Test func aFailureReachesThePopupAndATermsRefusalTheTermsSheet() async {
        let viewModel = makeViewModel()
        viewModel.reason = .other
        moderation.error = .reportFailed

        await viewModel.submit()
        #expect(harness.presentedError == .reportFailed && !viewModel.isSubmitted)
        #expect(harness.tournamentLogs(.error) == ["Report on tournament t1 failed: reportFailed"])

        moderation.error = .termsRequired
        await viewModel.submit()
        #expect(harness.presentedError == .termsRequired && harness.termsRequiredCount == 1)
    }
}
