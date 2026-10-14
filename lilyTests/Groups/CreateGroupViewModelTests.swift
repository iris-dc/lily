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
                                         locationService: harness.location,
                                         reporter: harness.reporter,
                                         logger: harness.logger,
                                         onCreated: harness.sink.record)
    }

    /// A complete public draft: the name and a place with its spot, as the sheet's `prepare()` would have proposed.
    private func fillDraft(of viewModel: CreateGroupViewModel? = nil) {
        let viewModel = viewModel ?? self.viewModel
        viewModel.draft.name = "Kreuzberg Kickers"
        viewModel.draft.locationName = "Görlitzer Park"
        viewModel.draft.coordinate = AppConfig.Location.mockCenter
    }

    @Test func aNewDraftIsPublicAndNotYetSubmittable() {
        #expect(viewModel.draft.visibility == .public)
        #expect(viewModel.issues == [.nameTooShort, .locationNameMissing])
        #expect(!viewModel.canSubmit)
    }

    /// Opening the sheet proposes the device's position as the spot, so a public group needs only its place named;
    /// a spot the user chose first is kept, and without a position the map stays the way to set it.
    @Test func prepareProposesTheDevicePositionAsTheSpot() async {
        harness.location.result = AppConfig.Location.mockCenter
        viewModel.draft.name = "Kreuzberg Kickers"

        await viewModel.prepare()
        #expect(viewModel.draft.coordinate == AppConfig.Location.mockCenter)
        #expect(viewModel.issues == [.locationNameMissing] && !viewModel.canSubmit)

        viewModel.draft.locationName = "Görlitzer Park"
        #expect(viewModel.canSubmit)

        let chosen = Coordinate(latitude: 1, longitude: 2)
        viewModel.draft.coordinate = chosen
        await viewModel.prepare()
        #expect(viewModel.draft.coordinate == chosen && harness.location.callCount == 1, "a chosen spot is not asked over")

        let unpositioned = CreateGroupViewModel(repository: harness.repository,
                                                store: harness.store,
                                                locationService: FakeLocationService(),
                                                reporter: harness.reporter,
                                                logger: harness.logger,
                                                onCreated: harness.sink.record)
        unpositioned.draft.name = "Kreuzberg Kickers"
        unpositioned.draft.locationName = "Görlitzer Park"
        await unpositioned.prepare()
        #expect(unpositioned.draft.coordinate == nil && unpositioned.issues == [.coordinateMissing])
    }

    @Test func submitCreatesTheGroupPutsItIntoMineAndHandsItOn() async {
        fillDraft()
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
        fillDraft()
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
        fillDraft()
        harness.repository.actionError = error
        harness.repository.result = .success([viewModel.draft.makeGroup(ownerName: "Me", now: .now)])

        await viewModel.submit()

        #expect(viewModel.createdGroup?.id == viewModel.draft.clientId)
        #expect(harness.presentedError == nil)
        #expect(harness.repository.fetchedGroupIDs == [viewModel.draft.clientId])
        #expect(harness.logs(.info).contains { $0.hasPrefix("Create landed for group") })
    }

    @Test func anotherOwnersGroupUnderTheIdKeepsTheFailure() async {
        fillDraft()
        harness.repository.actionError = AppError.groupCreationFailed
        harness.repository.result = .success([.fixture(id: viewModel.draft.clientId, role: .member)])

        await viewModel.submit()

        #expect(viewModel.createdGroup == nil)
        #expect(harness.presentedError == .groupCreationFailed)
        #expect(harness.store.groups.isEmpty)
        #expect(harness.logs(.error).filter { $0.hasPrefix("Create failed for group \(viewModel.draft.clientId):") }.count == 1)
    }

    /// A lookup that fails says nothing about the create: the user sees the create's failure and the log says the
    /// check was not possible.
    @Test func aFailedLookupKeepsTheFailure() async {
        fillDraft()
        harness.repository.actionError = AppError.network
        harness.repository.thrownError = AppError.groupsUnavailable

        await viewModel.submit()

        #expect(harness.presentedError == .network)
        #expect(harness.logs(.warning)
            .filter { $0.contains("Could not check whether group \(viewModel.draft.clientId) landed") }.count == 1)
    }

    /// Nothing under the draft's id is the check's answer, not a fault of the check: the failure reaches the popup,
    /// Mine stays as it was and the log notes the miss below warning.
    @Test func aCreateThatDidNotLandIsReportedWithoutAWarning() async {
        fillDraft()
        harness.repository.actionError = AppError.network
        harness.repository.result = .success([])

        await viewModel.submit()

        #expect(harness.presentedError == .network)
        #expect(harness.repository.fetchedGroupIDs == [viewModel.draft.clientId])
        #expect(harness.logs(.warning).isEmpty)
        #expect(harness.logs(.debug).contains { $0.contains("did not land") })
        #expect(harness.store.groups.isEmpty)
    }

    @Test func aRefusalWithCopyIsReportedWithoutALookup() async {
        fillDraft()
        harness.repository.actionError = AppError.contentRejected

        await viewModel.submit()

        #expect(harness.presentedError == .contentRejected)
        #expect(harness.repository.fetchedGroupIDs.isEmpty)
        #expect(harness.logs(.error).count == 1)
    }

    @Test func termsRequiredRaisesTheTermsSheet() async {
        fillDraft()
        harness.repository.actionError = AppError.termsRequired

        await viewModel.submit()

        #expect(harness.presentedError == .termsRequired && harness.termsRequiredCount == 1)
    }

    @Test func cancellationStaysQuiet() async {
        fillDraft()
        harness.repository.actionError = CancellationError()

        await viewModel.submit()

        #expect(harness.presentedError == nil && harness.logs().isEmpty && viewModel.createdGroup == nil)
    }
}
