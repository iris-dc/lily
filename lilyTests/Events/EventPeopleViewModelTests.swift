import Foundation
import Testing
@testable import lily

/// The pushed "Who's in" list: its own fetch, the event's host standing in before (or despite) an answer, and the
/// loaded flag that lets the screen call an empty Going section a fact rather than a failure's silence.
@MainActor
struct EventPeopleViewModelTests {
    private let host = EventParticipant.fixture(userId: "host", displayName: "Marta", isHost: true)
    private let you = EventParticipant.fixture(userId: TestFixtures.user.id, displayName: "Test Person")

    private func makeViewModel(repository: FakeEventRepository,
                               event: SportEvent = .fixture(capacity: 4, participants: 2, hostUserId: "host"))
        -> EventPeopleViewModel {
        let logger = SpyLogger()
        return EventPeopleViewModel(event: event,
                                    repository: repository,
                                    identity: FakeIdentityProvider(currentUserID: TestFixtures.user.id),
                                    errorCenter: ErrorCenter(logger: logger),
                                    logger: logger)
    }

    @Test func aLoadSplitsHostingFromGoingAndMarksTheCallersRow() async {
        let repository = FakeEventRepository()
        repository.participantsResult = .success([host, you])
        let viewModel = makeViewModel(repository: repository)

        await viewModel.load()

        #expect(viewModel.hasLoaded && viewModel.hosting == [host] && viewModel.going == [you])
        #expect(viewModel.isSelf(you) && !viewModel.isSelf(host))
        #expect(repository.participantsRequests == [viewModel.event.id])
    }

    @Test func theEventsOwnHostStandsInUntilAFetchAnswers() async {
        let repository = FakeEventRepository()
        repository.participantsResult = .failure(.eventsUnavailable)
        let viewModel = makeViewModel(repository: repository)
        #expect(viewModel.hosting.first?.userId == "host", "the event's host shows before any fetch")

        await viewModel.load()

        #expect(!viewModel.hasLoaded, "a failed fetch is not a loaded roster")
        #expect(viewModel.hosting.first?.isHost == true && viewModel.going.isEmpty)
    }

    /// An event from before hosts had ids offers no fallback row; the fetch's answer is the only hosting source.
    @Test func anEventWithoutAHostIdWaitsForTheList() async {
        let repository = FakeEventRepository()
        repository.participantsResult = .success([host, you])
        let viewModel = makeViewModel(repository: repository,
                                      event: .fixture(capacity: 4, participants: 2, hostUserId: nil))
        #expect(viewModel.hosting.isEmpty)

        await viewModel.load()

        #expect(viewModel.hosting == [host])
    }
}
