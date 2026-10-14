import Foundation
import Testing
@testable import lily

/// The tournament mock's wiring that `MockTournamentRepositoryTests` and the rules suite (both at the type-body limit)
/// leave untested: here the entry writes and the organiser's; in `+Results` the score range, the scopes, the guest and
/// the room's epoch. Same identity and clock as those suites; the stored properties are internal so the sibling file
/// reaches them.
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
    /// A start a day ahead: registration open for every seeded tournament without a deadline.
    var tomorrow: Date { Self.clock.addingTimeInterval(MockTournamentFixtures.secondsPerDay) }

    /// A tournament stored as the mock holds one, with its entries.
    func seed(_ tournament: Tournament, entries: [TournamentEntry] = []) {
        repository.details[tournament.id] = .fixture(tournament: tournament, entries: entries)
    }

    /// The Kickers Cup as its organiser (the caller) reads it, and its full team.
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

    /// A tournament at its cap refuses a join and keeps its count; one with a seat admits the caller.
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

    /// A team's name is judged against the backend's limits before anything is stored.
    @Test func aTeamNameOutsideTheLimitsIsRefused() async throws {
        let id = MockTournamentFixtures.kickersCupID
        let tooLong = String(repeating: "a", count: AppConfig.Tournaments.teamNameLength.upperBound + 1)
        await #expect(throws: AppError.tournamentActionFailed) { try await repository.join(id: id, teamName: "x") }
        await #expect(throws: AppError.tournamentActionFailed) { try await repository.join(id: id, teamName: tooLong) }
        let detail = try await repository.tournament(id: id)
        #expect(detail.tournament.entryCount == 4 && detail.entries.count == 4 && detail.tournament.myEntryId == nil)
    }

    /// A captain takes a teammate out: the entry stays with one member fewer and the count where it was.
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

    /// The organiser takes a player out of any team; the entry keeps its other members and the count stays.
    @Test func theOrganiserRemovesAPlayerFromATeam() async throws {
        let (cup, giants) = try await kickersCup()
        let first = try #require(giants.members.first)
        let remaining = try await repository.leave(id: cup.id, entryID: giants.id, userID: first.userId)
        #expect(remaining?.memberCount == giants.memberCount - 1 && remaining?.contains(userID: first.userId) == false)
        let detail = try await repository.tournament(id: cup.id)
        #expect(detail.tournament.entryCount == cup.tournament.entryCount)
    }

    /// A target the entry does not hold is the entry's refusal, whoever asks.
    @Test func leaveRefusesATargetNotInTheEntry() async throws {
        let (cup, giants) = try await kickersCup()
        await #expect(throws: AppError.entryNotFound) {
            try await repository.leave(id: cup.id, entryID: giants.id, userID: "nobody")
        }
        let detail = try await repository.tournament(id: cup.id)
        #expect(detail.entry(id: giants.id)?.memberCount == giants.memberCount)
    }

    /// The organiser drops a whole team: the entry is gone, the count drops by one, every member leaves the room, and
    /// the departure is logged once.
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

    /// An entry id that names nothing is its own refusal; once registration is over, nothing is removed.
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

    /// A tournament hosted in a group needs the group to exist and the caller allowed to create there. No stock
    /// community denies its members creation, so the Kickers (the caller a plain member) are stored with the
    /// permission off first.
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

    /// A cap below the entries already in is refused, as the backend's `CAPACITY_TOO_LOW`.
    @Test func updateRefusesACapBelowTheEntries() async throws {
        let (cup, _) = try await kickersCup()
        var draft = TournamentDraft(editing: cup.tournament)
        draft.maxEntries = cup.tournament.entryCount - 1
        await #expect(throws: AppError.capacityTooLow) { try await repository.update(id: cup.id, draft) }
        let detail = try await repository.tournament(id: cup.id)
        #expect(detail.tournament.maxEntries == cup.tournament.maxEntries)
    }

    /// A start below the format's minimum is refused and the tournament stays in registration.
    @Test func startNeedsEnoughEntries() async throws {
        let marker = MockTournamentFixtures.callerMarker
        seed(.fixture(id: "one", format: .singleElimination, entryCount: 1, startsAt: tomorrow, organizerUserId: marker),
             entries: [.fixture(id: "one-e1", tournamentId: "one")])
        await #expect(throws: AppError.notEnoughEntries) { try await repository.start(id: "one") }
        let detail = try await repository.tournament(id: "one")
        #expect(detail.tournament.status == .registration && detail.matches.isEmpty)
    }

    /// A completed tournament is locked: neither a start nor a cancel moves it.
    @Test func aFinishedTournamentTakesNoStartAndNoCancel() async throws {
        seed(.fixture(id: "done", status: .completed, organizerUserId: MockTournamentFixtures.callerMarker))
        await #expect(throws: AppError.tournamentLocked) { try await repository.start(id: "done") }
        await #expect(throws: AppError.tournamentLocked) { try await repository.cancel(id: "done") }
        #expect(repository.details["done"]?.tournament.status == .completed)
    }

    /// A second cancel answers the cancelled tournament as it is, like the backend's replay: nothing moves, nothing logs.
    @Test func cancellingACancelledTournamentReplays() async throws {
        let off = Tournament.fixture(id: "off", status: .cancelled, organizerUserId: MockTournamentFixtures.callerMarker)
        seed(off)
        let answer = try await repository.cancel(id: "off")
        #expect(answer.tournament.status == .cancelled && answer.tournament.updatedAt == off.updatedAt)
        #expect(!logger.messages(in: .tournaments, at: .info).contains("Mock tournament off cancelled"))
    }
}
