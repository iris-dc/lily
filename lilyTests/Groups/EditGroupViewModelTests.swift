import Foundation
import Testing
@testable import lily

@MainActor
struct EditGroupViewModelTests {
    private let harness = GroupHarness()
    private let group = SportGroup.fixture(id: "g", name: "Old name", role: .owner, location: Self.place)
    private static let place = EventLocation(name: "Görlitzer Park", coordinate: AppConfig.Location.mockCenter)
    private let viewModel: EditGroupViewModel

    init() {
        harness.repository.result = .success([group])
        harness.store.add(group)
        viewModel = EditGroupViewModel(group: group,
                                       repository: harness.repository,
                                       store: harness.store,
                                       reporter: harness.reporter,
                                       logger: harness.logger,
                                       onChange: harness.sink.record)
    }

    @Test func startsFromTheGroupWithNothingToSave() {
        #expect(viewModel.draft.name == "Old name" && viewModel.draft.clientId == "g")
        #expect(!viewModel.hasChanges && !viewModel.canSubmit)
        #expect(viewModel.issues.isEmpty)
    }

    @Test func submitSavesTheChangesIntoMineAndHandsThemOn() async {
        viewModel.draft.name = "New name"
        viewModel.draft.membersCanInvite = false
        #expect(viewModel.hasChanges && viewModel.canSubmit)

        await viewModel.submit()

        #expect(viewModel.updatedGroup?.name == "New name")
        #expect(viewModel.updatedGroup?.membersCanInvite == false)
        #expect(harness.store.groups.first?.name == "New name")
        #expect(harness.changed.map(\.name) == ["New name"])
        #expect(harness.repository.updatedDrafts.map(\.id) == ["g"])
        #expect(harness.logs(.info).contains("Group g updated"))
    }

    /// A public group from before places existed asks for one the first time it is edited; a private one does not.
    @Test func anOldPublicGroupWithoutAPlaceAsksForOneOnEdit() {
        let old = SportGroup.fixture(id: "old", name: "Old name", role: .owner)
        let viewModel = EditGroupViewModel(group: old,
                                           repository: harness.repository,
                                           store: harness.store,
                                           reporter: harness.reporter,
                                           logger: harness.logger,
                                           onChange: harness.sink.record)
        #expect(viewModel.issues == [.locationNameMissing] && !viewModel.canSubmit)

        viewModel.draft.locationName = "Görlitzer Park"
        viewModel.draft.coordinate = AppConfig.Location.mockCenter
        #expect(viewModel.hasChanges && viewModel.canSubmit)

        let privateGroup = SportGroup.fixture(id: "p", visibility: .private, role: .owner)
        let privateViewModel = EditGroupViewModel(group: privateGroup,
                                                  repository: harness.repository,
                                                  store: harness.store,
                                                  reporter: harness.reporter,
                                                  logger: harness.logger,
                                                  onChange: harness.sink.record)
        #expect(privateViewModel.issues.isEmpty)
    }

    @Test func anInvalidDraftCannotBeSaved() {
        viewModel.draft.name = "ab"

        #expect(viewModel.hasChanges && !viewModel.canSubmit)
        #expect(viewModel.issue(for: .nameTooShort, .nameTooLong) == .nameTooShort)
    }

    @Test func aFailureReachesThePopup() async {
        viewModel.draft.name = "New name"
        harness.repository.actionError = AppError.insufficientRole

        await viewModel.submit()

        #expect(viewModel.updatedGroup == nil)
        #expect(harness.presentedError == .insufficientRole)
        #expect(harness.store.groups.first?.name == "Old name")
        #expect(harness.logs(.error).count == 1)
    }

    @Test func cancellationStaysQuiet() async {
        viewModel.draft.name = "New name"
        harness.repository.actionError = CancellationError()

        await viewModel.submit()

        #expect(harness.presentedError == nil && harness.logs().isEmpty)
    }
}
