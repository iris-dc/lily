import Foundation
import Testing
@testable import lily

/// The backend's two caps on open tournaments, mirrored: `tournaments.max-per-user` on entering (organiser or player, in
/// registration or in progress; finished and cancelled ones never count, a caller with a row in the room is let through
/// to the room's own refusals) and `tournaments.max-organized-open` on a create (a repeat under a stored id replays).
extension MockTournamentRefusalsTests {
    // MARK: Caps

    private var callerMarker: String { MockTournamentFixtures.callerMarker }
    private var target: Tournament { .fixture(id: "target", teamSize: 2, maxEntries: 8, entryCount: 1, startsAt: tomorrow) }

    /// Seeds open tournaments with the caller in an entry until they are in `maxPerUser`, counting the fixtures they
    /// are in already (the Kickers Cup as organiser, Tuesday Table Tennis as a player).
    private func fillTheMembershipCap(status: TournamentStatus = .registration) -> [String] {
        let ids = (0..<max(0, AppConfig.Tournaments.maxPerUser - repository.openInRoomsCount)).map { "in-\($0)" }
        for id in ids {
            let mine = TournamentEntry.fixture(id: "\(id)-e1", tournamentId: id, name: "Me", captainUserId: callerMarker)
            seed(.fixture(id: id, status: status, entryCount: 1, startsAt: tomorrow), entries: [mine])
        }
        return ids
    }

    /// Seeds open tournaments organised by the caller until they organise `maxOrganizedOpen` (the Kickers Cup counts).
    private func fillTheOrganizerCap(status: TournamentStatus = .registration) -> [String] {
        let ids = (0..<max(0, AppConfig.Tournaments.maxOrganizedOpen - repository.openOrganizedCount)).map { "org-\($0)" }
        for id in ids {
            seed(.fixture(id: id, status: status, startsAt: tomorrow, organizerUserId: callerMarker))
        }
        return ids
    }

    private func seedTarget() {
        seed(target, entries: [.fixture(id: "target-e1", tournamentId: "target", name: "Marta's pair")])
    }

    @Test func twentyOpenTournamentsRefuseAnotherEntry() async throws {
        _ = fillTheMembershipCap()
        seedTarget()
        #expect(repository.openInRoomsCount == AppConfig.Tournaments.maxPerUser)

        await #expect(throws: AppError.tournamentMembershipLimit) {
            try await repository.join(id: "target", teamName: "Us")
        }
        await #expect(throws: AppError.tournamentMembershipLimit) {
            try await repository.joinTeam(id: "target", entryID: "target-e1")
        }
        #expect(repository.details["target"]?.tournament.entryCount == 1, "nothing was written")
    }

    /// The team's name is judged before the cap, as `DynamoTournamentEntryService.join` validates the body first.
    @Test func aBadTeamNameIsRefusedBeforeTheCap() async throws {
        _ = fillTheMembershipCap()
        seedTarget()

        await #expect(throws: AppError.tournamentActionFailed) { try await repository.join(id: "target", teamName: "x") }
        #expect(repository.details["target"]?.tournament.entryCount == 1, "nothing was written")
    }

    @Test(arguments: [TournamentStatus.completed, .cancelled])
    func finishedAndCancelledTournamentsNeverCountTowardsTheCap(status: TournamentStatus) async throws {
        _ = fillTheMembershipCap(status: status)
        seedTarget()
        #expect(repository.openInRoomsCount < AppConfig.Tournaments.maxPerUser)

        let entry = try await repository.join(id: "target", teamName: "Us")
        #expect(entry.contains(userID: Self.callerID))
    }

    /// At the cap, a caller with a row in the room reaches the room's own conditions, as the backend's `requireRoom`
    /// lets a row holder through; here the condition that answers is that they are in already.
    @Test func aCallerAlreadyInTheRoomIsLetThroughAtTheCap() async throws {
        let entered = try #require(fillTheMembershipCap().first)

        await #expect(throws: AppError.alreadyEntered) { try await repository.join(id: entered, teamName: nil) }
    }

    @Test func tenOpenTournamentsRefuseAnotherCreate() async throws {
        let organised = try #require(fillTheOrganizerCap().first)
        let draft = TournamentDraft.fixture(now: now)
        #expect(repository.openOrganizedCount == AppConfig.Tournaments.maxOrganizedOpen)

        await #expect(throws: AppError.tournamentLimit) { try await repository.create(draft) }
        #expect(repository.details[draft.clientId] == nil)

        _ = try await repository.cancel(id: organised)
        let created = try await repository.create(draft)
        #expect(created.id == draft.clientId, "a cancelled tournament frees the slot")
    }

    /// At the cap, a group the caller may not create in answers the cap, as Laurel's `requireOrganizerSlot` runs before
    /// the transaction that judges the role; a group that is gone still answers first, as `groupFor` reads it before.
    @Test func atTheCapTheCapAnswersAfterTheGroupAndBeforeTheRole() async throws {
        _ = fillTheOrganizerCap()
        let kickers = try #require(groups.find(MockGroupFixtures.kickersID))
        var permissions = GroupDraft(editing: kickers)
        permissions.membersCanCreateEvents = false
        groups.store(kickers.updating(with: permissions))
        var draft = TournamentDraft.fixture(now: now)
        draft.group = MockGroupFixtures.ref(for: kickers.id)

        await #expect(throws: AppError.tournamentLimit) { try await repository.create(draft) }

        draft.group = EventGroupRef(id: "missing", name: "Gone", visibility: .private, isDeleted: false)
        await #expect(throws: AppError.groupNotFound) { try await repository.create(draft) }
        #expect(repository.details[draft.clientId] == nil)
    }

    @Test func aReplayAtTheOrganisersCapAnswersTheSameTournament() async throws {
        let draft = TournamentDraft.fixture(now: now)
        let first = try await repository.create(draft)
        _ = fillTheOrganizerCap()
        #expect(repository.openOrganizedCount == AppConfig.Tournaments.maxOrganizedOpen)

        let replayed = try await repository.create(draft)
        #expect(replayed == first)
        #expect(logger.hasLine(in: .tournaments, mentioning: "replayed", first.id))
    }

    /// Open as the backend counts: in registration or in progress; a status this build does not know never counts.
    @Test func openMeansInRegistrationOrInProgress() {
        #expect(MockTournamentRepository.isOpen(.fixture(status: .registration)))
        #expect(MockTournamentRepository.isOpen(.fixture(status: .inProgress)))
        #expect(!MockTournamentRepository.isOpen(.fixture(status: .completed)))
        #expect(!MockTournamentRepository.isOpen(.fixture(status: .cancelled)))
        #expect(!MockTournamentRepository.isOpen(.fixture(status: .unknown("paused"))))
    }
}
