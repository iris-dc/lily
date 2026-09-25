import Foundation
import Testing
@testable import lily

@MainActor
struct CreateGroupViewModelTests {
    /// Failures after which the backend may have the group anyway.
    nonisolated private static let unknownOutcomes: [AppError] = [.network, .groupCreationFailed]

    private let harness = GroupHarness()
    private let viewModel: CreateGroupViewModel

    init() {
        viewModel = CreateGroupViewModel(repository: harness.repository,
                                         store: harness.store,
                                         reporter: harness.reporter,
                                         logger: harness.logger,
                                         onCreated: harness.sink.record)
    }

    @Test func aNewDraftIsPublicAndNotYetSubmittable() {
        #expect(viewModel.draft.visibility == .public)
        #expect(viewModel.issues == [.nameTooShort])
        #expect(!viewModel.canSubmit)
        #expect(viewModel.issue(for: .nameTooShort, .nameTooLong) == .nameTooShort)
        #expect(viewModel.issue(for: .descriptionTooLong) == nil)
    }

    @Test func submitCreatesTheGroupPutsItIntoMineAndHandsItOn() async {
        viewModel.draft.name = "Kreuzberg Kickers"
        viewModel.draft.visibility = .private

        await viewModel.submit()

        let created = viewModel.createdGroup
        #expect(created?.id == viewModel.draft.clientId && created?.role == .owner)
        #expect(harness.store.groups.map(\.id) == [viewModel.draft.clientId])
        #expect(harness.changed.count == 1)
        #expect(harness.repository.createdDrafts.count == 1)
        #expect(harness.logs(.info).contains("Group created \(viewModel.draft.clientId) (private)"))
    }

    @Test func aSecondSubmitWhileInFlightIsDropped() async {
        viewModel.draft.name = "Kreuzberg Kickers"
        harness.repository.holdsRequests = true
        let first = Task { await viewModel.submit() }
        await settle(until: { harness.repository.createdDrafts.count == 1 })

        await viewModel.submit()
        #expect(harness.repository.createdDrafts.count == 1 && viewModel.isSubmitting)

        harness.repository.releaseRequests()
        await first.value
        #expect(viewModel.createdGroup != nil && !viewModel.isSubmitting)
    }

    /// The same client id travels with every attempt, so the group the backend already has is found and accepted.
    @Test(arguments: unknownOutcomes) func anUnknownOutcomeAcceptsTheGroupTheCallerOwns(_ error: AppError) async {
        viewModel.draft.name = "Kreuzberg Kickers"
        harness.repository.actionError = error
        harness.repository.result = .success([viewModel.draft.makeGroup(ownerName: "Me", now: .now)])

        await viewModel.submit()

        #expect(viewModel.createdGroup?.id == viewModel.draft.clientId)
        #expect(harness.presentedError == nil)
        #expect(harness.repository.fetchedGroupIDs == [viewModel.draft.clientId])
        #expect(harness.logs(.info).contains { $0.hasPrefix("Create landed for group") })
    }

    @Test func anotherOwnersGroupUnderTheIdKeepsTheFailure() async {
        viewModel.draft.name = "Kreuzberg Kickers"
        harness.repository.actionError = AppError.groupCreationFailed
        harness.repository.result = .success([.fixture(id: viewModel.draft.clientId, role: .member)])

        await viewModel.submit()

        #expect(viewModel.createdGroup == nil)
        #expect(harness.presentedError == .groupCreationFailed)
        #expect(harness.store.groups.isEmpty)
    }

    @Test func aFailedLookupKeepsTheFailure() async {
        viewModel.draft.name = "Kreuzberg Kickers"
        harness.repository.actionError = AppError.network
        harness.repository.result = .success([])

        await viewModel.submit()

        #expect(harness.presentedError == .network)
        #expect(harness.logs(.warning).contains { $0.hasPrefix("Could not check whether the create landed") })
    }

    @Test func aRefusalWithCopyIsReportedWithoutALookup() async {
        viewModel.draft.name = "Kreuzberg Kickers"
        harness.repository.actionError = AppError.contentRejected

        await viewModel.submit()

        #expect(harness.presentedError == .contentRejected)
        #expect(harness.repository.fetchedGroupIDs.isEmpty)
        #expect(harness.logs(.error).count == 1)
    }

    @Test func termsRequiredRaisesTheTermsSheet() async {
        viewModel.draft.name = "Kreuzberg Kickers"
        harness.repository.actionError = AppError.termsRequired

        await viewModel.submit()

        #expect(harness.presentedError == .termsRequired && harness.termsRequiredCount == 1)
    }

    @Test func cancellationStaysQuiet() async {
        viewModel.draft.name = "Kreuzberg Kickers"
        harness.repository.actionError = CancellationError()

        await viewModel.submit()

        #expect(harness.presentedError == nil && harness.logs().isEmpty && viewModel.createdGroup == nil)
    }
}
