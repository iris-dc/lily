import Foundation
import Testing
@testable import lily

@MainActor
struct EditGroupViewModelTests {
    private let harness = GroupHarness()
    private let group = SportGroup.fixture(id: "g", name: "Old name", role: .owner)
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
