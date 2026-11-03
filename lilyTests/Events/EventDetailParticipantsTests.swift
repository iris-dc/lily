import Foundation
import Testing
@testable import lily

/// Who is in, on the detail: loaded for signed-in callers on appear and again after every join, leave or refetch; the
/// host line links to the host's profile when the caller may open it.
@MainActor
struct EventDetailParticipantsTests {
    private let host = EventParticipant.fixture(userId: "host", displayName: "Marta", isHost: true)
    private let you = EventParticipant.fixture(userId: TestFixtures.user.id, displayName: "Test Person")

    private func makeHarness(event: SportEvent = .fixture(capacity: 4, participants: 1, hostUserId: "host", isJoined: false))
        -> EventDetailHarness {
        EventDetailHarness(event: event)
    }

    @Test func participantsLoadOnAppearForSignedInCallers() async {
        let harness = makeHarness()
        harness.repository.participantsResult = .success([host])
        #expect(harness.viewModel.showsParticipants && harness.viewModel.participants.isEmpty)

        await harness.viewModel.loadParticipants()

        #expect(harness.viewModel.participants == [host] && !harness.viewModel.isLoadingParticipants)
        #expect(harness.repository.participantsRequests == ["e"])
        #expect(!harness.viewModel.isSelf(host))
    }

    /// Names are members-level information: a guest sees the count only and nothing is requested for them.
    @Test func guestsGetNoParticipantsAndNoRequest() async {
        let harness = makeHarness()
        harness.identity.currentUserID = nil

        await harness.viewModel.loadParticipants()

        #expect(!harness.viewModel.showsParticipants && harness.viewModel.participants.isEmpty)
        #expect(harness.repository.participantsRequests.isEmpty)
    }

    @Test func aJoinReloadsTheParticipantsAndTheCallersRowIsSelf() async {
        let harness = makeHarness()
        await harness.viewModel.loadParticipants()
        harness.repository.participantsResult = .success([host, you])

        await harness.viewModel.join()

        #expect(harness.repository.participantsRequests == ["e", "e"])
        #expect(harness.viewModel.participants == [host, you])
        #expect(harness.viewModel.isSelf(you) && !harness.viewModel.isSelf(host))
    }

    @Test func aLeaveReloadsTheParticipants() async {
        let harness = makeHarness(event: .fixture(capacity: 4, participants: 2, hostUserId: "host", isJoined: true))

        await harness.viewModel.leave()

        #expect(harness.repository.participantsRequests == ["e"])
    }

    /// A refusal refetches the event; whoever changed it may have changed the list too.
    @Test func theRefetchAfterARefusalReloadsTheParticipants() async {
        let harness = makeHarness()
        harness.repository.participationError = AppError.eventFull

        await harness.viewModel.join()

        #expect(harness.repository.fetchedEventIDs == ["e"])
        #expect(harness.repository.participantsRequests == ["e"])
    }

    @Test func aFailedLoadReachesThePopupAndKeepsTheLastList() async {
        let harness = makeHarness()
        harness.repository.participantsResult = .success([host])
        await harness.viewModel.loadParticipants()
        harness.repository.participantsResult = .failure(.eventsUnavailable)

        await harness.viewModel.loadParticipants()

        #expect(harness.viewModel.participants == [host])
        #expect(harness.errorCenter.current?.error == .eventsUnavailable)
        #expect(harness.logger.hasLine(in: .events, at: .warning, mentioning: "Loading participants of event e failed"))
    }

    /// The view's task going away cancels the load; a cancellation is nobody's failure.
    @Test func aCancelledParticipantsLoadReportsNothingAndKeepsTheLastList() async {
        let harness = makeHarness()
        harness.repository.participantsResult = .success([host])
        await harness.viewModel.loadParticipants()
        harness.repository.thrownError = CancellationError()

        await harness.viewModel.loadParticipants()

        #expect(harness.viewModel.participants == [host])
        #expect(harness.errorCenter.current == nil && !harness.viewModel.isLoadingParticipants)
        #expect(!harness.logger.hasLine(in: .events, at: .warning, mentioning: "Loading participants"))
    }

    /// The host's profile opens for a signed-in caller who is not the host and when the host is known at all.
    @Test func theHostLineLinksToTheHostForOtherSignedInCallersOnly() {
        let harness = makeHarness()
        #expect(harness.viewModel.hostProfile == UserProfileDestination(userId: "host", displayName: "h"))

        harness.identity.currentUserID = "host"
        #expect(harness.viewModel.hostProfile == nil, "the host is the caller")

        harness.identity.currentUserID = nil
        #expect(harness.viewModel.hostProfile == nil, "guests open no profiles")

        #expect(makeHarness(event: .fixture(hostUserId: nil)).viewModel.hostProfile == nil,
                "a fixture without a host id has no link")
    }
}
