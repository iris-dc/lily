import Foundation
import Testing
@testable import lily

/// The report sheet's model: nothing goes out without a reason, a send answers the thanks state, a failure the popup.
@MainActor
struct ReportViewModelTests {
    private let harness = GroupHarness()
    private let moderation = FakeModerationRepository()

    private func makeViewModel(target: ReportTarget = .tournament(id: "t1"),
                               title: String = AppBranding.Tournaments.report) -> ReportViewModel {
        ReportViewModel(target: target,
                        title: title,
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

    @Test func reportingAMessageSendsItsIdAndGroup() async {
        let viewModel = makeViewModel(target: .message(id: "m1", groupID: "g1"), title: AppBranding.Moderation.reportMessage)
        #expect(viewModel.title == "Report message")
        viewModel.reason = .inappropriate

        await viewModel.submit()

        let report = moderation.reports.first
        #expect(report?.targetType == .message && report?.targetId == "m1" && report?.groupId == "g1")
        #expect(harness.logs(.info).contains { $0.hasPrefix("Report ") && $0.hasSuffix(" filed on message m1") })
        #expect(harness.tournamentLogs().isEmpty, "a message's report is logged under the groups")
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

    @Test func aCommentOfTheLimitPlusAReturnStillSends() async {
        let viewModel = makeViewModel()
        viewModel.reason = .spam
        let atTheLimit = String(repeating: "x", count: AppConfig.Moderation.commentMaxLength)
        viewModel.comment = atTheLimit + "\n"
        #expect(viewModel.canSubmit, "the newline the field inserts is not sent, so it does not count")

        await viewModel.submit()

        #expect(moderation.reports.first?.comment == atTheLimit && viewModel.isSubmitted)
    }

    @Test func aSecondSubmitWhileOneIsOutIsDropped() async {
        let viewModel = makeViewModel()
        viewModel.reason = .spam
        moderation.holdsRequests = true

        let first = Task { await viewModel.submit() }
        await settle(until: { viewModel.isSubmitting })
        #expect(!viewModel.canSubmit)
        await viewModel.submit()
        #expect(moderation.reports.count == 1, "the repeat is dropped rather than filed as a second report")

        moderation.releaseRequests()
        await first.value
        #expect(viewModel.isSubmitted && !viewModel.isSubmitting)
    }

    @Test func cancellationStaysQuiet() async {
        let viewModel = makeViewModel()
        viewModel.reason = .other
        moderation.error = CancellationError()

        await viewModel.submit()

        #expect(!viewModel.isSubmitted && harness.presentedError == nil)
        #expect(harness.tournamentLogs().isEmpty && harness.logs().isEmpty)
    }

    @Test func aFailureReachesThePopupAndATermsRefusalTheTermsSheet() async {
        let viewModel = makeViewModel()
        viewModel.reason = .other
        moderation.error = AppError.reportFailed

        await viewModel.submit()
        #expect(harness.presentedError == .reportFailed && !viewModel.isSubmitted)
        #expect(harness.tournamentLogs(.error).count == 1)
        #expect(harness.tournamentLogs(.error).mentioning("tournament t1", "\(AppError.reportFailed)").count == 1)

        moderation.error = AppError.termsRequired
        await viewModel.submit()
        #expect(harness.presentedError == .termsRequired && harness.termsRequiredCount == 1)
    }
}
