import Foundation
import Testing
@testable import lily

/// The mock's invites into an event: who may be invited into the fixture games, and the backend's refusals, the
/// tournament invite mock's twin.
@MainActor
struct MockEventInviteRepositoryTests {
    private let identity = FakeIdentityProvider(currentUserID: TestFixtures.user.id)
    private let logger = SpyLogger()
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let sunset = MockEventFixtures.sunsetEventID
    /// A fixture the stride leaves unjoined, so the caller has no invite rights there.
    private let unjoined = "mock-event-1"

    private func makeRepositories(clock: @escaping () -> Date) -> (events: MockEventRepository,
                                                                   invites: MockEventInviteRepository) {
        let groups = MockGroupRepository(identity: identity, logger: logger) { now }
        let events = MockEventRepository(now: now, identity: identity, logger: logger)
        events.rooms = groups
        let invites = MockEventInviteRepository(groups: groups, events: events, identity: identity, logger: logger, now: clock)
        return (events, invites)
    }

    private func makeRepositories() -> (events: MockEventRepository, invites: MockEventInviteRepository) {
        makeRepositories { now }
    }

    /// A participant of the joined sunset fixture may invite the pool minus everyone already in the game.
    @Test func candidatesAreThePoolMinusEveryoneInTheEvent() async throws {
        let (events, invites) = makeRepositories()
        let inEvent = Set(try await events.participants(eventId: sunset).map(\.userId))

        let candidates = try await invites.candidates(groupID: sunset)

        #expect(!candidates.isEmpty && candidates.map(\.displayName) == candidates.map(\.displayName).sorted())
        #expect(candidates.allSatisfy { !inEvent.contains($0.userId) }, "nobody in the game is offered")
        #expect(!candidates.contains { $0.userId == TestFixtures.user.id })
        #expect(candidates.allSatisfy { !$0.isInvited })
    }

    @Test func invitingMarksTheCandidateInvitedAndReplaysTheSameInvite() async throws {
        let (_, invites) = makeRepositories()
        let candidate = try #require(try await invites.candidates(groupID: sunset).first)

        let sent = try await invites.invite(groupID: sunset, userID: candidate.userId)

        #expect(sent.eventId == sunset && sent.groupId == nil && sent.tournamentId == nil)
        #expect(sent.inviteeUserId == candidate.userId && sent.status == .pending && sent.createdAt == now)
        #expect(try await invites.candidates(groupID: sunset).first { $0.userId == candidate.userId }?.isInvited == true)
        #expect(try await invites.invite(groupID: sunset, userID: candidate.userId) == sent, "a repeat replays it")
        #expect(logger.messages(in: .events, at: .info)
            .contains("Mock invite \(sent.id) into event \(sunset) sent to \(candidate.userId)"))
    }

    /// Only the host and participants invite, while the event has not started; someone in already is no invitee.
    @Test func theBackendsRefusals() async throws {
        let (_, invites) = makeRepositories()
        let hostID = MockGroupFixtures.memberID(for: "Marta")

        await #expect(throws: AppError.inviteeAlreadyJoined) { try await invites.invite(groupID: sunset, userID: hostID) }
        await #expect(throws: AppError.userNotFound) { try await invites.invite(groupID: sunset, userID: "nobody") }
        await #expect(throws: AppError.cannotInviteToEvent) { try await invites.candidates(groupID: unjoined) }
        await #expect(throws: AppError.eventNotFound) { try await invites.candidates(groupID: "nope") }

        identity.currentUserID = nil
        await #expect(throws: AppError.sessionExpired) { try await invites.candidates(groupID: sunset) }
    }

    /// Once the game started the invites close (`EVENT_STARTED`), though the caller still participates.
    @Test func aStartedEventRefusesInvites() async throws {
        let start = try #require(MockEventFixtures.make(now: now, count: 1).first?.startsAt)
        let (_, invites) = makeRepositories { start.addingTimeInterval(60) }

        await #expect(throws: AppError.eventStarted) { try await invites.candidates(groupID: sunset) }
        await #expect(throws: AppError.eventStarted) { try await invites.invite(groupID: sunset, userID: "anyone") }
    }
}
