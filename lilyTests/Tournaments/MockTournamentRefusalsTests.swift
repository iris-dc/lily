import Foundation
import Testing
@testable import lily

@MainActor
struct MockTournamentRefusalsTests {
    static let callerID = "mock-apple"
    static let clock = Date(timeIntervalSince1970: 1_800_000_000)
    let identity = FakeIdentityProvider(currentUserID: callerID)
    let logger = SpyLogger()
    let groups: MockGroupRepository
    let repository: MockTournamentRepository

    init() {
        groups = MockGroupRepository(identity: identity, logger: logger, now: { Self.clock })
        repository = MockTournamentRepository(groups: groups, identity: identity, logger: logger, now: { Self.clock })
    }

    var now: Date { Self.clock }
    /// Keeps registration open for a seeded tournament without a deadline.
    var tomorrow: Date { Self.clock.addingTimeInterval(MockTournamentFixtures.secondsPerDay) }

    func seed(_ tournament: Tournament, entries: [TournamentEntry] = []) {
        repository.details[tournament.id] = .fixture(tournament: tournament, entries: entries)
    }

    /// The caller organises the Kickers Cup; the Görli Giants are its full team.
    func kickersCup() async throws -> (detail: TournamentDetail, giants: TournamentEntry) {
        let detail = try await repository.tournament(id: MockTournamentFixtures.kickersCupID)
        let giants = try #require(detail.entries.first { $0.name == "Görli Giants" })
        return (detail, giants)
    }

    private func twoPlayers(in id: String) -> [TournamentEntry] {
        [.fixture(id: "\(id)-e1", tournamentId: id),
         .fixture(id: "\(id)-e2", tournamentId: id, name: "Jonas", captainUserId: "seed-jonas", seed: 2)]
    }

    // MARK: Entries

    @Test func joinRefusesAFullTournament() async throws {
        seed(.fixture(id: "full", maxEntries: 2, entryCount: 2, startsAt: tomorrow), entries: twoPlayers(in: "full"))
        await #expect(throws: AppError.tournamentFull) { try await repository.join(id: "full", teamName: nil) }
        #expect(repository.details["full"]?.tournament.entryCount == 2)

        seed(.fixture(id: "seat", maxEntries: 3, entryCount: 2, startsAt: tomorrow), entries: twoPlayers(in: "seat"))
        let entry = try await repository.join(id: "seat", teamName: nil)
        let seated = try await repository.tournament(id: "seat")
        #expect(entry.contains(userID: Self.callerID) && seated.tournament.entryCount == 3)
        #expect(seated.tournament.myEntryId == entry.id)
    }

    @Test func aTeamNameOutsideTheLimitsIsRefused() async throws {
        let id = MockTournamentFixtures.kickersCupID
        let tooLong = String(repeating: "a", count: AppConfig.Tournaments.teamNameLength.upperBound + 1)
        await #expect(throws: AppError.tournamentActionFailed) { try await repository.join(id: id, teamName: "x") }
        await #expect(throws: AppError.tournamentActionFailed) { try await repository.join(id: id, teamName: tooLong) }
        let detail = try await repository.tournament(id: id)
        #expect(detail.tournament.entryCount == 4 && detail.entries.count == 4 && detail.tournament.myEntryId == nil)
    }

    @Test func aCaptainRemovesATeammate() async throws {
        let marker = MockTournamentFixtures.callerMarker
        let team = TournamentEntry.fixture(id: "us",
                                           tournamentId: "teams",
                                           name: "Us",
                                           captainUserId: marker,
                                           members: [EntryMember(userId: marker, displayName: "You"),
                                                     EntryMember(userId: "u-2", displayName: "Two")])
        seed(.fixture(id: "teams", teamSize: 3, entryCount: 1, startsAt: tomorrow), entries: [team])

        let remaining = try await repository.leave(id: "teams", entryID: "us", userID: "u-2")

        #expect(remaining?.memberCount == 1 && remaining?.contains(userID: Self.callerID) == true)
        let detail = try await repository.tournament(id: "teams")
        #expect(detail.tournament.entryCount == 1 && detail.tournament.myEntryId == "us")
    }

    @Test func theOrganiserRemovesAPlayerFromATeam() async throws {
        let (cup, giants) = try await kickersCup()
        let first = try #require(giants.members.first)
        let remaining = try await repository.leave(id: cup.id, entryID: giants.id, userID: first.userId)
        #expect(remaining?.memberCount == giants.memberCount - 1 && remaining?.contains(userID: first.userId) == false)
        let detail = try await repository.tournament(id: cup.id)
        #expect(detail.tournament.entryCount == cup.tournament.entryCount)
    }

    @Test func leaveRefusesATargetNotInTheEntry() async throws {
        let (cup, giants) = try await kickersCup()
        await #expect(throws: AppError.entryNotFound) {
            try await repository.leave(id: cup.id, entryID: giants.id, userID: "nobody")
        }
        let detail = try await repository.tournament(id: cup.id)
        #expect(detail.entry(id: giants.id)?.memberCount == giants.memberCount)
    }

    @Test func theOrganiserRemovesAWholeEntry() async throws {
        let (cup, giants) = try await kickersCup()
        let roomBefore = try await groups.group(id: cup.id)

        try await repository.removeEntry(id: cup.id, entryID: giants.id)

        let detail = try await repository.tournament(id: cup.id)
        #expect(detail.entry(id: giants.id) == nil && detail.tournament.entryCount == cup.tournament.entryCount - 1)
        let room = try await groups.group(id: cup.id)
        #expect(room.memberCount == roomBefore.memberCount - giants.memberCount)
        let lines = logger.messages(in: .tournaments, at: .info)
        #expect(lines.filter { $0.contains("entry \(giants.id) removed by the organiser") }.count == 1)
    }

    @Test func removeEntryRefusesAMissingEntryAndAClosedRegistration() async throws {
        let (cup, giants) = try await kickersCup()
        await #expect(throws: AppError.entryNotFound) { try await repository.removeEntry(id: cup.id, entryID: "nope") }

        let stored = try #require(repository.details[cup.id])
        repository.details[cup.id] = stored.replacing(tournament: stored.tournament.starting(at: now))
        await #expect(throws: AppError.registrationClosed) {
            try await repository.removeEntry(id: cup.id, entryID: giants.id)
        }
        #expect(repository.details[cup.id]?.entry(id: giants.id) != nil)
    }

    // MARK: Organiser writes

    @Test func createInAGroupNeedsTheGroupAndTheRole() async throws {
        var draft = TournamentDraft.fixture(now: now)
        draft.group = EventGroupRef(id: "missing", name: "Gone", visibility: .private, isDeleted: false)
        await #expect(throws: AppError.groupNotFound) { try await repository.create(draft) }

        let kickers = try #require(groups.find(MockGroupFixtures.kickersID))
        var permissions = GroupDraft(editing: kickers)
        permissions.membersCanCreateEvents = false
        groups.store(kickers.updating(with: permissions))
        draft.group = MockGroupFixtures.ref(for: kickers.id)
        await #expect(throws: AppError.insufficientRole) { try await repository.create(draft) }
        #expect(repository.details[draft.clientId] == nil)
    }

    @Test func updateRefusesACapBelowTheEntries() async throws {
        let (cup, _) = try await kickersCup()
        var draft = TournamentDraft(editing: cup.tournament)
        draft.maxEntries = cup.tournament.entryCount - 1
        await #expect(throws: AppError.capacityTooLow) { try await repository.update(id: cup.id, draft) }
        let detail = try await repository.tournament(id: cup.id)
        #expect(detail.tournament.maxEntries == cup.tournament.maxEntries)
    }

    @Test func startNeedsEnoughEntries() async throws {
        let marker = MockTournamentFixtures.callerMarker
        seed(.fixture(id: "one", format: .singleElimination, entryCount: 1, startsAt: tomorrow, organizerUserId: marker),
             entries: [.fixture(id: "one-e1", tournamentId: "one")])
        await #expect(throws: AppError.notEnoughEntries) { try await repository.start(id: "one") }
        let detail = try await repository.tournament(id: "one")
        #expect(detail.tournament.status == .registration && detail.matches.isEmpty)
    }

    @Test func aFinishedTournamentTakesNoStartAndNoCancel() async throws {
        seed(.fixture(id: "done", status: .completed, organizerUserId: MockTournamentFixtures.callerMarker))
        await #expect(throws: AppError.tournamentLocked) { try await repository.start(id: "done") }
        await #expect(throws: AppError.tournamentLocked) { try await repository.cancel(id: "done") }
        #expect(repository.details["done"]?.tournament.status == .completed)
    }

    @Test func cancellingACancelledTournamentReplays() async throws {
        let off = Tournament.fixture(id: "off", status: .cancelled, organizerUserId: MockTournamentFixtures.callerMarker)
        seed(off)
        let answer = try await repository.cancel(id: "off")
        #expect(answer.tournament.status == .cancelled && answer.tournament.updatedAt == off.updatedAt)
        #expect(!logger.messages(in: .tournaments, at: .info).contains("Mock tournament off cancelled"))
    }
}
