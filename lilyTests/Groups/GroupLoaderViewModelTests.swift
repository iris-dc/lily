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

    /// The view's task re-runs on every return from a pushed screen; the group on screen is kept and nothing is asked.
    @Test func aLoadedDetailIsKeptWhenTheTaskReRuns() async {
        let group = SportGroup.fixture(id: "g")
        harness.repository.result = .success([group])
        let viewModel = makeViewModel()

        await viewModel.loadIfNeeded()
        await viewModel.loadIfNeeded()

        #expect(viewModel.state == .loaded(group))
        #expect(harness.repository.fetchedGroupIDs == ["g"])
    }

    @Test func aFailedReloadKeepsTheLoadedGroupAndShowsThePopup() async {
        let group = SportGroup.fixture(id: "g")
        harness.repository.result = .success([group])
        let viewModel = makeViewModel()
        await viewModel.load()
        harness.repository.thrownError = AppError.groupsUnavailable

        await viewModel.load()

        #expect(viewModel.state == .loaded(group))
        #expect(harness.presentedError == .groupsUnavailable)
        #expect(harness.logs(.error).count == 1)
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

    @Test func tryAgainAfterAFailureLoadsTheGroup() async {
        let group = SportGroup.fixture(id: "g")
        harness.repository.thrownError = AppError.groupsUnavailable
        let viewModel = makeViewModel()
        await viewModel.loadIfNeeded()
        #expect(viewModel.state == .failed)
        harness.repository.thrownError = nil
        harness.repository.result = .success([group])

        await viewModel.load()

        #expect(viewModel.state == .loaded(group))
        #expect(harness.repository.fetchedGroupIDs == ["g", "g"])
    }

    /// The screen's Try again is the retry; the task re-running on its own asks for nothing after a failure.
    @Test func aFailedLoadIsNotRetriedByTheTaskAlone() async {
        harness.repository.thrownError = AppError.groupsUnavailable
        let viewModel = makeViewModel()
        await viewModel.loadIfNeeded()
        #expect(viewModel.state == .failed)
        let requestsAfterFailure = harness.repository.fetchedGroupIDs.count

        await viewModel.loadIfNeeded()

        #expect(viewModel.state == .failed)
        #expect(harness.repository.fetchedGroupIDs.count == requestsAfterFailure)
    }

    /// A cancelled first attempt leaves `.loading`, so the task's next run fetches.
    @Test func cancellationStaysQuiet() async {
        let group = SportGroup.fixture(id: "g")
        harness.repository.thrownError = CancellationError()
        let viewModel = makeViewModel()

        await viewModel.load()

        #expect(viewModel.state == .loading)
        #expect(harness.presentedError == nil && harness.logs().isEmpty)

        harness.repository.thrownError = nil
        harness.repository.result = .success([group])
        await viewModel.loadIfNeeded()

        #expect(viewModel.state == .loaded(group))
    }
}
