import Foundation
import Testing
@testable import lily

/// Who is in, on the detail: loaded for signed-in callers on appear and again after every join, leave or refetch; the
/// host line links to the host's profile when the caller may open it. The main detail suite is at its file limit.
@MainActor
struct EventDetailParticipantsTests {
    private let repository = FakeEventRepository()
    private let identity = FakeIdentityProvider(currentUserID: TestFixtures.user.id)
    private let logger = SpyLogger()
    private let errorCenter: ErrorCenter
    private let host = EventParticipant.fixture(userId: "host", displayName: "Marta", isHost: true)
    private let you = EventParticipant.fixture(userId: TestFixtures.user.id, displayName: "Test Person")

    init() {
        errorCenter = ErrorCenter(logger: logger)
    }

    private func makeViewModel(event: SportEvent = .fixture(capacity: 4, participants: 1, hostUserId: "host", isJoined: false))
        -> EventDetailViewModel {
        repository.result = .success([event])
        return EventDetailViewModel(event: event,
                                    repository: repository,
                                    identity: identity,
                                    errorCenter: errorCenter,
                                    recorder: SpyInteractionRecorder(),
                                    logger: logger,
                                    tryAgainDelay: .zero,
                                    onChange: { _ in })
    }

    @Test func participantsLoadOnAppearForSignedInCallers() async {
        repository.participantsResult = .success([host])
        let viewModel = makeViewModel()
        #expect(viewModel.showsParticipants && viewModel.participants.isEmpty)

        await viewModel.loadParticipants()

        #expect(viewModel.participants == [host] && !viewModel.isLoadingParticipants)
        #expect(repository.participantsRequests == ["e"])
        #expect(!viewModel.isSelf(host))
    }

    /// Names are members-level information: a guest sees the count only and nothing is requested for them.
    @Test func guestsGetNoParticipantsAndNoRequest() async {
        identity.currentUserID = nil
        let viewModel = makeViewModel()

        await viewModel.loadParticipants()

        #expect(!viewModel.showsParticipants && viewModel.participants.isEmpty)
        #expect(repository.participantsRequests.isEmpty)
    }

    @Test func aJoinReloadsTheParticipantsAndTheCallersRowIsSelf() async {
        let viewModel = makeViewModel()
        await viewModel.loadParticipants()
        repository.participantsResult = .success([host, you])

        await viewModel.join()

        #expect(repository.participantsRequests == ["e", "e"])
        #expect(viewModel.participants == [host, you])
        #expect(viewModel.isSelf(you) && !viewModel.isSelf(host))
    }

    @Test func aLeaveReloadsTheParticipants() async {
        let viewModel = makeViewModel(event: .fixture(capacity: 4, participants: 2, hostUserId: "host", isJoined: true))

        await viewModel.leave()

        #expect(repository.participantsRequests == ["e"])
    }

    /// A refusal refetches the event; whoever changed it may have changed the list too.
    @Test func theRefetchAfterARefusalReloadsTheParticipants() async {
        let viewModel = makeViewModel()
        repository.participationError = AppError.eventFull

        await viewModel.join()

        #expect(repository.fetchedEventIDs == ["e"])
        #expect(repository.participantsRequests == ["e"])
    }

    @Test func aFailedLoadReachesThePopupAndKeepsTheLastList() async {
        repository.participantsResult = .success([host])
        let viewModel = makeViewModel()
        await viewModel.loadParticipants()
        repository.participantsResult = .failure(.eventsUnavailable)

        await viewModel.loadParticipants()

        #expect(viewModel.participants == [host])
        #expect(errorCenter.current?.error == .eventsUnavailable)
        #expect(logger.messages(in: .events, at: .warning).contains { $0.contains("Loading participants of event e failed") })
    }

    /// The host's profile opens for a signed-in caller who is not the host and when the host is known at all.
    @Test func theHostLineLinksToTheHostForOtherSignedInCallersOnly() {
        let viewModel = makeViewModel()
        #expect(viewModel.hostProfile == UserProfileDestination(userId: "host", displayName: "h"))

        identity.currentUserID = "host"
        #expect(viewModel.hostProfile == nil, "the host is the caller")

        identity.currentUserID = nil
        #expect(viewModel.hostProfile == nil, "guests open no profiles")

        identity.currentUserID = TestFixtures.user.id
        #expect(makeViewModel(event: .fixture(hostUserId: nil)).hostProfile == nil, "a fixture without a host id has no link")
    }
}
