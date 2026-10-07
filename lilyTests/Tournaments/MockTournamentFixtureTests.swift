import Foundation
import Testing
@testable import lily

/// The fixtures L3 added to the mock: the private Padel Open the caller is invited into, and the caller's scheduled
/// table-tennis match. The main mock suite sits at its type-body limit.
@MainActor
struct MockTournamentFixtureTests {
    private static let clock = Date(timeIntervalSince1970: 1_800_000_000)
    private let identity = FakeIdentityProvider(currentUserID: TestFixtures.user.id)
    private let logger = SpyLogger()
    private let groups: MockGroupRepository
    private let repository: MockTournamentRepository

    private var now: Date { Self.clock }

    init() {
        let now = Self.clock
        groups = MockGroupRepository(identity: identity, logger: logger, now: { now })
        repository = MockTournamentRepository(groups: groups, identity: identity, logger: logger, now: { now })
    }

    /// Private and not the caller's: off Explore, off Home, unreadable until an invite names the caller (then readable,
    /// as the backend's `invitedUserIds` makes it); its room is in the group mock without a membership, so Mine never
    /// lists it until the caller enters.
    @Test func thePadelOpenIsReachableByInviteAlone() async throws {
        let id = MockTournamentFixtures.padelOpenID
        #expect(MockTournamentFixtures.ids == [MockTournamentFixtures.kickersCupID, MockTournamentFixtures.tableTennisID, id])

        await #expect(throws: AppError.tournamentNotFound) { try await repository.tournament(id: id) }
        await #expect(throws: AppError.tournamentNotFound) { try await repository.join(id: id, teamName: nil) }
        #expect(try await repository.tournaments(in: .upcoming, near: nil).map(\.id) == [MockTournamentFixtures.kickersCupID])
        let mineBefore = try await repository.tournaments(in: .mine, near: nil)
        let roomsBefore = try await groups.groups(in: .mine, cursor: nil, near: nil).items
        #expect(!mineBefore.contains { $0.id == id } && !roomsBefore.contains { $0.id == id })
        #expect(groups.find(id)?.isTournamentRoom == true && groups.find(id)?.isMember == false)

        repository.noteInvitee(of: id)
        let invited = try await repository.tournament(id: id)
        #expect(!invited.tournament.hasEntered && invited.tournament.entryCount == 4, "an invitee reads it before entering")
        let entry = try await repository.join(id: id, teamName: nil)
        let detail = try await repository.tournament(id: id)
        #expect(entry.contains(userID: TestFixtures.user.id) && detail.tournament.myEntryId == entry.id)
        #expect(detail.tournament.name == "Padel Open" && detail.tournament.visibility == .private)
        #expect(detail.tournament.teamSize == 1)
        #expect(detail.tournament.organizerName == "Noor" && detail.entries.count == 5 && detail.tournament.entryCount == 5)
        let mineAfter = try await repository.tournaments(in: .mine, near: nil)
        #expect(mineAfter.contains { $0.id == id } && groups.find(id)?.isMember == true, "entering joins the room")
        #expect(try await groups.members(id: id).count == 5, "Noor, Aiko, Sam, Tom and the caller")
    }

    /// The caller's third-round match against Dev carries the time and the hall, so the Matches list shows them and the
    /// inbox's match reminder names the same match.
    @Test func theCallersNextTableTennisMatchIsScheduled() async throws {
        let detail = try await repository.tournament(id: MockTournamentFixtures.tableTennisID)
        let match = try #require(detail.match(id: MockTournamentFixtures.tableTennisScheduledMatchID))

        #expect(match.status == .scheduled && !match.isDecided && match.contains(entryID: detail.tournament.myEntryId))
        #expect(match.scheduledAt == now.addingTimeInterval(AppConfig.Inbox.mockReminderLead))
        #expect(match.location == MockTournamentFixtures.tableTennisLocation)
        #expect(detail.matches.filter { $0.status == .scheduled }.count == 1)
        let opponent = try #require(detail.opponent(in: match, of: TestFixtures.user.id))
        #expect(opponent.name == "Dev")
        #expect(detail.opponent(in: match, of: "mock-user-noor") == nil, "not Noor's match")
    }

    /// The organiser's schedule (the caller organises the Kickers Cup): the match takes the time and place, is
    /// `scheduled`, and an empty one clears both; a player of Marta's table tennis may not schedule.
    @Test func theOrganiserSchedulesAndClearsAMatch() async throws {
        let id = MockTournamentFixtures.kickersCupID
        _ = try await repository.join(id: id, teamName: "Late Bloomers")
        _ = try await repository.start(id: id)
        let when = now.addingTimeInterval(7_200)
        let place = EventLocation(name: "Pitch 2", coordinate: AppConfig.Location.mockCenter)

        let schedule = MatchSchedule(scheduledAt: when, location: place)
        let scheduled = try await repository.schedule(id: id, matchID: "r01p002", schedule)
        #expect(scheduled.status == .scheduled && scheduled.scheduledAt == when && scheduled.location == place)
        #expect(try await repository.tournament(id: id).match(id: "r01p002") == scheduled, "stored")

        let cleared = try await repository.schedule(id: id, matchID: "r01p002", MatchSchedule())
        #expect(cleared.status == .pending && cleared.scheduledAt == nil && cleared.location == nil)

        await #expect(throws: AppError.notOrganizer) {
            try await repository.schedule(id: MockTournamentFixtures.tableTennisID, matchID: "r03p001", MatchSchedule())
        }
    }
}
