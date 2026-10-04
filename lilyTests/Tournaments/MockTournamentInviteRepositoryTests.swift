import Foundation
import Testing
@testable import lily

/// The mock's invites into a tournament: who may be invited into the fixture tournaments, and the backend's refusals.
@MainActor
struct MockTournamentInviteRepositoryTests {
    private let identity = FakeIdentityProvider(currentUserID: TestFixtures.user.id)
    private let logger = SpyLogger()
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let cup = MockTournamentFixtures.kickersCupID
    private let tableTennis = MockTournamentFixtures.tableTennisID
    private let padelOpen = MockTournamentFixtures.padelOpenID

    private func makeRepositories() -> (tournaments: MockTournamentRepository, invites: MockTournamentInviteRepository) {
        let groups = MockGroupRepository(identity: identity, logger: logger) { now }
        let tournaments = MockTournamentRepository(groups: groups, identity: identity, logger: logger) { now }
        let invites = MockTournamentInviteRepository(groups: groups,
                                                     tournaments: tournaments,
                                                     identity: identity,
                                                     logger: logger) { now }
        return (tournaments, invites)
    }

    /// Once in Noor's Padel Open, the caller may invite the people of their communities and the game hosts who are not
    /// among its players; Noor, Aiko, Sam and Tom are out. The Kickers Cup has nobody left to invite: every fixture
    /// person the caller knows plays in one of its teams.
    @Test func candidatesAreThePoolMinusEveryoneInTheTournament() async throws {
        let (tournaments, invites) = makeRepositories()
        tournaments.noteInvitee(of: padelOpen)
        _ = try await tournaments.join(id: padelOpen, teamName: nil)

        let candidates = try await invites.candidates(groupID: padelOpen)

        #expect(!candidates.isEmpty && candidates.map(\.displayName) == candidates.map(\.displayName).sorted())
        #expect(!candidates.contains { MockTournamentFixtures.padelOpenPlayers.contains($0.displayName) }, "nobody in is offered")
        #expect(candidates.contains { $0.displayName == "Marta" } && !candidates.contains { $0.userId == TestFixtures.user.id })
        #expect(candidates.allSatisfy { !$0.isInvited })
        #expect(try await invites.candidates(groupID: cup).isEmpty, "the cup's teams hold everyone the caller knows")
    }

    @Test func invitingMarksTheCandidateInvitedAndReplaysTheSameInvite() async throws {
        let (tournaments, invites) = makeRepositories()
        tournaments.noteInvitee(of: padelOpen)
        _ = try await tournaments.join(id: padelOpen, teamName: nil)
        let candidate = try #require(try await invites.candidates(groupID: padelOpen).first)

        let sent = try await invites.invite(groupID: padelOpen, userID: candidate.userId)

        #expect(sent.tournamentId == padelOpen && sent.groupId == nil && sent.inviteeUserId == candidate.userId)
        #expect(sent.status == .pending && sent.createdAt == now)
        #expect(try await invites.candidates(groupID: padelOpen).first { $0.userId == candidate.userId }?.isInvited == true)
        #expect(try await invites.invite(groupID: padelOpen, userID: candidate.userId) == sent, "a repeat replays it")
        #expect(logger.messages(in: .tournaments, at: .info)
            .contains("Mock invite \(sent.id) into tournament \(padelOpen) sent to \(candidate.userId)"))
    }

    /// Only entrants and the organiser invite, while registration is open; someone in already is no invitee.
    @Test func theBackendsRefusals() async {
        let (_, invites) = makeRepositories()

        await #expect(throws: AppError.inviteeAlreadyEntered) {
            try await invites.invite(groupID: cup, userID: MockGroupFixtures.memberID(for: "Marta"))
        }
        await #expect(throws: AppError.userNotFound) { try await invites.invite(groupID: cup, userID: "nobody") }
        await #expect(throws: AppError.registrationClosed) { try await invites.candidates(groupID: tableTennis) }
        await #expect(throws: AppError.tournamentNotFound) { try await invites.candidates(groupID: padelOpen) }
        await #expect(throws: AppError.tournamentNotFound) { try await invites.candidates(groupID: "nope") }

        identity.currentUserID = nil
        await #expect(throws: AppError.sessionExpired) { try await invites.candidates(groupID: cup) }
    }

    /// An invitee who has not entered yet reads the tournament but may not invite into it.
    @Test func anInviteeWhoIsNotInCannotInvite() async throws {
        let (tournaments, invites) = makeRepositories()
        tournaments.noteInvitee(of: padelOpen)

        _ = try await tournaments.tournament(id: padelOpen)
        await #expect(throws: AppError.cannotInviteToTournament) { try await invites.candidates(groupID: padelOpen) }
    }
}
