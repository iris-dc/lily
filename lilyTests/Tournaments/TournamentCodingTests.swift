import Foundation
import Testing
@testable import lily

/// The wire shapes of the tournaments plan (section 2.1), decoded with the app's conventions.
struct TournamentCodingTests {
    @Test func tournamentDecodesEveryContractField() throws {
        let tournament = try ContractSamples.decode(Tournament.self, from: ContractSamples.tournament)

        #expect(tournament.id == "9c1f2e3d-4b5a-4c6d-8e7f-0a1b2c3d4e5f" && tournament.name == "Kickers Cup")
        #expect(tournament.description == "Eight teams, one evening" && tournament.type == .football)
        #expect(tournament.format == .singleElimination && tournament.status == .registration && tournament.isPublic)
        #expect(tournament.teamSize == 5 && tournament.maxEntries == 8 && tournament.entryCount == 4 && !tournament.allowsDraws)
        #expect(tournament.startsAt == APIJSONCoding.parseInstant("2026-10-18T10:00:00Z"))
        #expect(tournament.registrationClosesAt == APIJSONCoding.parseInstant("2026-10-16T10:00:00Z"))
        #expect(tournament.locationName == "Görlitzer Park pitch" && tournament.location.coordinate.latitude == 52.496)
        #expect(tournament.organizerUserId == "u-1" && tournament.organizerName == "Apple Tester")
        #expect(tournament.group?.name == "Kreuzberg Kickers" && tournament.group?.isLinkable == true)
        #expect(tournament.channelEpoch == 1 && tournament.myEntryId == nil && tournament.winnerEntryId == nil)
        #expect(tournament.startedAt == nil && tournament.completedAt == nil && tournament.updatedAt == nil)
        #expect(tournament.isTeam && !tournament.hasEntered && !tournament.isFull && tournament.isListed)
    }

    @Test func aStartedTournamentDecodesItsOptionalsAndTheCallersEntry() throws {
        let tournament = try ContractSamples.decode(Tournament.self, from: ContractSamples.startedTournament)

        #expect(tournament.status == .inProgress && tournament.format == .roundRobin && tournament.type == .tableTennis)
        #expect(tournament.myEntryId == "01J9ENTRY0000000000000003" && tournament.hasEntered && tournament.group == nil)
        #expect(tournament.startedAt == APIJSONCoding.parseInstant("2026-10-02T18:00:00Z") && tournament.channelEpoch == 2)
        #expect(!tournament.isListed, "Explore lists tournaments in registration only")
        #expect(!tournament.isRegistrationOpen(now: .now))
    }

    @Test func entryDecodesItsMembersInJoinOrder() throws {
        let entry = try ContractSamples.decode(TournamentEntry.self, from: ContractSamples.entry)

        #expect(entry.id == "01J9ENTRY0000000000000001" && entry.name == "Görli Giants" && entry.seed == 1)
        #expect(entry.captainUserId == "seed-marta" && entry.status == .registered && entry.isRegistered)
        #expect(entry.members.map(\.displayName) == ["Marta", "Jonas"])
        #expect(entry.contains(userID: "seed-jonas") && !entry.contains(userID: "u-1") && entry.isCaptain("seed-marta"))
        #expect(!entry.isFull(teamSize: 5) && entry.isFull(teamSize: 2))
    }

    @Test func matchDecodesWithAbsentOptionalsAndWithEveryField() throws {
        let pending = try ContractSamples.decode(TournamentMatch.self, from: ContractSamples.match)
        #expect(pending.id == "r01p002" && pending.round == 1 && pending.position == 2 && pending.status == .pending)
        #expect(pending.entryAId == "01J9ENTRY0000000000000004" && pending.hasBothSides && !pending.isDisputed)
        #expect(pending.scoreA == nil && pending.winnerEntryId == nil && pending.scheduledAt == nil && pending.location == nil)
        #expect(pending.nextMatchId == "r02p001" && pending.nextSlot == .b && pending.isReadyForResult)

        let confirmed = try ContractSamples.decode(TournamentMatch.self, from: ContractSamples.confirmedMatch)
        #expect(confirmed.status == .confirmed && confirmed.scoreA == 3 && confirmed.scoreB == 1 && confirmed.isDecided)
        #expect(confirmed.winnerEntryId == "01J9ENTRY0000000000000001" && confirmed.location?.name == "Table two")
        #expect(confirmed.reportedBy == "seed-marta" && confirmed.confirmedBy == "seed-noor")
        #expect(confirmed.confirmedAt == APIJSONCoding.parseInstant("2026-10-07T20:05:00Z") && !confirmed.isReadyForResult)
    }

    @Test func standingAndDetailDecode() throws {
        let standing = try ContractSamples.decode(TournamentStanding.self, from: ContractSamples.standing)
        #expect(standing.rank == 1 && standing.played == 1 && standing.won == 1 && standing.points == 3)
        #expect(standing.scoreDifference == 2)

        let detail = try ContractSamples.decode(TournamentDetail.self, from: ContractSamples.tournamentDetail)
        #expect(detail.tournament.name == "Kickers Cup" && detail.entries.count == 1)
        #expect(detail.matches.isEmpty && detail.standings.isEmpty)
        #expect(detail.entry(id: "01J9ENTRY0000000000000001")?.name == "Görli Giants" && detail.myEntry == nil)

        let started = try ContractSamples.decode(TournamentDetail.self, from: ContractSamples.startedTournamentDetail)
        #expect(started.matches.count == 1 && started.standings.count == 1 && started.match(id: "r01p001") != nil)
        #expect(started.entry(containing: "seed-jonas")?.id == "01J9ENTRY0000000000000001")
    }

    @Test func theListIsAPageWithoutACursor() throws {
        let page = try ContractSamples.decode(Page<Tournament>.self, from: ContractSamples.tournamentList)
        #expect(page.items.map(\.name) == ["Kickers Cup"] && page.nextCursor == nil)
    }

    /// A tournament's room is a `Group` of kind `tournament` with the fields the backend fixes.
    @Test func aTournamentRoomDecodesAsAGroupOfKindTournament() throws {
        let room = try ContractSamples.decode(SportGroup.self, from: ContractSamples.tournamentRoom)

        #expect(room.kind == .tournament && room.isTournamentRoom && !room.isCommunity && !room.isDirect)
        #expect(room.name == "Kickers Cup" && room.maxMembers == 41 && room.memberCount == 12 && room.role == .owner)
        #expect(!room.membersCanCreateEvents && !room.membersCanInvite && room.counterpart == nil)
        let encoder = APIJSONCoding.makeEncoder()
        let json = try #require(String(bytes: try encoder.encode(room), encoding: .utf8))
        #expect(json.contains(#""kind":"tournament""#))
    }

    @Test func wireNamesAreSnakeCase() throws {
        #expect(TournamentFormat.singleElimination.rawValue == "single_elimination")
        #expect(TournamentFormat.roundRobin.rawValue == "round_robin")
        #expect(TournamentStatus.inProgress.rawValue == "in_progress" && EntryStatus.withdrawn.rawValue == "withdrawn")
        #expect(MatchStatus.walkover.rawValue == "walkover" && MatchSlot.b.rawValue == "b")
        #expect(GroupKind(wireName: "tournament") == .tournament && GroupKind.tournament.wireName == "tournament")
    }

    /// The bodies the repository sends, key for key as the backend's requests name them.
    @Test func createPayloadFollowsTheDraftAndOmitsTheVisibilityWithAGroup() throws {
        var draft = TournamentDraft.fixture()
        draft.description = "  "
        draft.registrationClosesAt = draft.startsAt.addingTimeInterval(-3600)
        let standalone = try #require(CreateTournamentPayload(draft: draft))
        #expect(standalone.clientTournamentId == draft.clientId && standalone.name == "Kickers Cup")
        #expect(standalone.description == nil && standalone.visibility == .public && standalone.groupId == nil)
        #expect(standalone.allowsDraws == EventType.football.allowsDrawsByDefault && standalone.teamSize == 1)
        #expect(standalone.maxEntries == 8 && standalone.registrationClosesAt == draft.registrationClosesAt)
        #expect(TestFixtures.isBackendEventId(standalone.clientTournamentId))

        draft.group = EventGroupRef(id: "g1", name: "Kickers", visibility: .private, isDeleted: false)
        let hosted = try #require(CreateTournamentPayload(draft: draft))
        #expect(hosted.groupId == "g1" && hosted.visibility == nil, "a hosted tournament takes the group's visibility")

        let json = try #require(String(bytes: try APIJSONCoding.makeEncoder().encode(hosted), encoding: .utf8))
        #expect(json.contains(#""clientTournamentId""#) && json.contains(#""groupId":"g1""#) && !json.contains("visibility"))
        #expect(!json.contains("null"), "optionals are omitted, never null")
        #expect(CreateTournamentPayload(draft: .fixture(coordinate: nil)) == nil)
    }

    @Test func updatePayloadCarriesWhatTheOrganiserMayChange() throws {
        let tournament = Tournament.fixture(allowsDraws: true)
        var draft = TournamentDraft(editing: tournament)
        draft.name = "Wednesday Table Tennis"
        draft.maxEntries = 10
        let payload = try #require(UpdateTournamentPayload(draft: draft))
        #expect(payload.name == "Wednesday Table Tennis" && payload.maxEntries == 10 && payload.allowsDraws)
        #expect(payload.startsAt == tournament.startsAt && payload.registrationClosesAt == nil && payload.description == nil)
        let json = try #require(String(bytes: try APIJSONCoding.makeEncoder().encode(payload), encoding: .utf8))
        #expect(!json.contains("format") && !json.contains("teamSize") && !json.contains("null"))
    }

    @Test func entryAndMatchPayloadsEncode() throws {
        let encoder = APIJSONCoding.makeEncoder()
        func json(_ body: some Encodable) throws -> String? {
            String(bytes: try encoder.encode(body), encoding: .utf8)
        }
        #expect(try json(CreateEntryPayload(name: nil)) == "{}")
        #expect(try json(CreateEntryPayload(name: "Görli Giants")) == #"{"name":"Görli Giants"}"#)
        let result = try JSONDecoder().decode([String: Int].self, from: encoder.encode(MatchResultPayload(scoreA: 3, scoreB: 1)))
        #expect(result == ["scoreA": 3, "scoreB": 1])
        #expect(try json(WalkoverPayload(winnerEntryId: "e1")) == #"{"winnerEntryId":"e1"}"#)
        #expect(try json(MatchSchedulePayload(schedule: MatchSchedule())) == "{}")
    }

    @Test func tournamentCopiesKeepWhatTheyShould() throws {
        let tournament = Tournament.fixture(entryCount: 2)
        let joined = tournament.updatingEntries(count: 3, myEntryId: "e3", at: .now)
        #expect(joined.entryCount == 3 && joined.myEntryId == "e3" && joined.name == tournament.name)
        let started = joined.starting(at: Date(timeIntervalSince1970: 1_800_000_000))
        #expect(started.status == .inProgress && started.startedAt != nil && started.entryCount == 3)
        let completed = started.completing(winnerEntryId: "e3", at: .now)
        #expect(completed.status == .completed && completed.winnerEntryId == "e3" && completed.status.isOver)
        #expect(tournament.cancelling(at: .now).status == .cancelled)
        #expect(tournament.entriesDescription == "2 of 8 players")
        #expect(Tournament.fixture(teamSize: 5, maxEntries: 8, entryCount: 4).entriesDescription == "4 of 8 teams of 5")
    }

    /// Entries open while in registration and, with a deadline, before it; the count fills towards the cap.
    @Test func registrationFollowsTheStatusAndTheDeadline() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let open = Tournament.fixture(startsAt: now.addingTimeInterval(86_400))
        #expect(open.isRegistrationOpen(now: now))
        let deadline = Tournament.fixture(startsAt: now.addingTimeInterval(86_400),
                                          registrationClosesAt: now.addingTimeInterval(-1))
        #expect(!deadline.isRegistrationOpen(now: now))
        #expect(!Tournament.fixture(status: .inProgress).isRegistrationOpen(now: now))
        let full = Tournament.fixture(maxEntries: 4, entryCount: 4)
        #expect(full.isFull && full.fillRatio == 1 && Tournament.fixture(maxEntries: 8, entryCount: 2).fillRatio == 0.25)
        #expect(Tournament.fixture(maxEntries: 8, entryCount: 3).canStart, "a round robin starts with three")
        #expect(!Tournament.fixture(maxEntries: 8, entryCount: 2).canStart)
    }

    @Test func anEntryPassesTheCaptaincyWhenTheCaptainLeaves() throws {
        let team = TournamentEntry.fixture(captainUserId: "a",
                                           members: [EntryMember(userId: "a", displayName: "A"),
                                                     EntryMember(userId: "b", displayName: "B")])
        let withoutCaptain = try #require(team.removing(userID: "a"))
        #expect(withoutCaptain.captainUserId == "b" && withoutCaptain.memberCount == 1)
        #expect(withoutCaptain.removing(userID: "b") == nil, "an emptied entry is gone")
        #expect(team.adding(EntryMember(userId: "c", displayName: "C")).memberCount == 3)
    }
}
