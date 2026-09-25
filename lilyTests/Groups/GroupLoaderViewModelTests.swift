import Foundation
import Testing
@testable import lily

@MainActor
struct GroupLoaderViewModelTests {
    private let harness = GroupHarness()
    private let ref = EventGroupRef(id: "g", name: "Group", visibility: .public, isDeleted: false)

    private func makeViewModel() -> GroupLoaderViewModel {
        GroupLoaderViewModel(ref: ref, repository: harness.repository, errorCenter: harness.errorCenter, logger: harness.logger)
    }

    @Test func loadsTheGroupBehindTheReference() async {
        let group = SportGroup.fixture(id: "g")
        harness.repository.result = .success([group])
        let viewModel = makeViewModel()
        #expect(viewModel.state == .loading)

        await viewModel.load()

        #expect(viewModel.state == .loaded(group))
        #expect(harness.repository.fetchedGroupIDs == ["g"])
    }

    /// Deleted, or private and the caller is out: the screen says so, no popup.
    @Test func aMissingGroupIsNotFoundWithoutAPopup() async {
        harness.repository.result = .success([])
        let viewModel = makeViewModel()

        await viewModel.load()

        #expect(viewModel.state == .notFound)
        #expect(harness.presentedError == nil)
        #expect(harness.logs(.info).count == 1)
    }

    @Test func anyOtherFailureReachesThePopup() async {
        harness.repository.thrownError = AppError.groupsUnavailable
        let viewModel = makeViewModel()

        await viewModel.load()

        #expect(viewModel.state == .failed)
        #expect(harness.presentedError == .groupsUnavailable)
    }

    @Test func cancellationStaysQuiet() async {
        harness.repository.thrownError = CancellationError()
        let viewModel = makeViewModel()

        await viewModel.load()

        #expect(viewModel.state == .loading)
        #expect(harness.presentedError == nil && harness.logs().isEmpty)
    }
}
