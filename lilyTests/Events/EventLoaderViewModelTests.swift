import Foundation
import Testing
@testable import lily

/// The loader behind an event room's info button, the group loader's twin.
@MainActor
struct EventLoaderViewModelTests {
    private let repository = FakeEventRepository()
    private let logger = SpyLogger()
    private let errorCenter: ErrorCenter
    private let destination = EventDestination(id: "e", name: "Sunset 5-a-side")

    init() {
        errorCenter = ErrorCenter(logger: logger)
    }

    private var presentedError: AppError? { errorCenter.current?.error }

    private func makeViewModel() -> EventLoaderViewModel {
        EventLoaderViewModel(destination: destination, repository: repository, errorCenter: errorCenter, logger: logger)
    }

    @Test func loadsTheEventBehindTheDestination() async {
        let event = SportEvent.fixture(id: "e")
        repository.result = .success([event])
        let viewModel = makeViewModel()
        #expect(viewModel.state == .loading)

        await viewModel.load()

        #expect(viewModel.state == .loaded(event))
        #expect(repository.fetchedEventIDs == ["e"])
    }

    /// The view's task re-runs on every return from a pushed screen; the event on screen is kept and nothing is asked.
    @Test func aLoadedDetailIsKeptWhenTheTaskReRuns() async {
        repository.result = .success([.fixture(id: "e")])
        let viewModel = makeViewModel()

        await viewModel.loadIfNeeded()
        await viewModel.loadIfNeeded()

        #expect(repository.fetchedEventIDs == ["e"])
    }

    @Test func aFailedReloadKeepsTheLoadedEventAndShowsThePopup() async {
        let event = SportEvent.fixture(id: "e")
        repository.result = .success([event])
        let viewModel = makeViewModel()
        await viewModel.load()
        repository.thrownError = AppError.eventsUnavailable

        await viewModel.load()

        #expect(viewModel.state == .loaded(event))
        #expect(presentedError == .eventsUnavailable)
        #expect(logger.messages(in: .events, at: .error).count == 1)
    }

    /// Deleted, or a private group's event the caller may not read: the screen says so, no popup.
    @Test func aMissingEventIsNotFoundWithoutAPopup() async {
        repository.result = .success([])
        let viewModel = makeViewModel()

        await viewModel.load()

        #expect(viewModel.state == .notFound)
        #expect(presentedError == nil)
        #expect(logger.messages(in: .events, at: .info).count == 1)
    }

    @Test func anyOtherFailureReachesThePopupAndTryAgainLoads() async {
        repository.thrownError = AppError.eventsUnavailable
        let viewModel = makeViewModel()

        await viewModel.loadIfNeeded()
        #expect(viewModel.state == .failed && presentedError == .eventsUnavailable)

        let event = SportEvent.fixture(id: "e")
        repository.thrownError = nil
        repository.result = .success([event])
        await viewModel.load()
        #expect(viewModel.state == .loaded(event))
    }
}
