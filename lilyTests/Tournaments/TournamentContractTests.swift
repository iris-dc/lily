import Foundation
import Testing
@testable import lily

/// Laurel's strict-JSON literals, verbatim from `TournamentControllerIt`, `TournamentMatchControllerIt` and
/// `GroupControllerIt` (laurel `cd983f6`), decoded with the app's conventions, so a key, a nesting or a wire value that
/// moves on either side fails a test rather than a reading. `ContractSamples` are Lily's own samples of the same shapes;
/// these are the backend's, in `LaurelTournamentJSON`.
struct TournamentContractTests {
    private typealias Laurel = LaurelTournamentJSON

    @Test func theTournamentDecodesWithEveryFieldLaurelWrites() throws {
        let tournament = try ContractSamples.decode(Tournament.self, from: Laurel.tournament)
        #expect(tournament.id == Laurel.id && tournament.name == "Kickers Cup")
        #expect(tournament.description == "Four teams, one Sunday." && tournament.type == .football)
        #expect(tournament.format == .singleElimination && tournament.status == .registration && tournament.isPublic)
        #expect(tournament.teamSize == 5 && tournament.maxEntries == 4 && tournament.entryCount == 1 && tournament.allowsDraws)
        #expect(!tournament.permitsDraws, "a knockout refuses a draw whatever allowsDraws says")
        #expect(tournament.startsAt == APIJSONCoding.parseInstant("2026-10-18T10:00:00Z"))
        #expect(tournament.registrationClosesAt == APIJSONCoding.parseInstant("2026-10-17T10:00:00Z"))
        #expect(tournament.location == Laurel.feld)
        #expect(tournament.organizerUserId == "sub-1" && tournament.organizerName == "Marta")
        #expect(tournament.group == EventGroupRef(id: "g1", name: "Kreuzberg Kickers", visibility: .public, isDeleted: false))
        #expect(tournament.channelEpoch == 1 && tournament.myEntryId == Laurel.entryID)
        #expect(tournament.winnerEntryId == nil && tournament.startedAt == nil && tournament.completedAt == nil)
        #expect(tournament.createdAt == APIJSONCoding.parseInstant("2026-10-04T12:00:00Z") && tournament.updatedAt == nil)
    }

    @Test func theEntryTheDetailAndTheListDecode() throws {
        let entry = try ContractSamples.decode(TournamentEntry.self, from: Laurel.entry)
        #expect(entry.id == Laurel.entryID && entry.tournamentId == Laurel.id && entry.name == "Kreuzberg FC")
        #expect(entry.captainUserId == "sub-1" && entry.seed == 1 && entry.status == .registered)
        #expect(entry.members == [EntryMember(userId: "sub-1", displayName: "Marta"),
                                  EntryMember(userId: "sub-2", displayName: "Jonas")])
        #expect(entry.createdAt == APIJSONCoding.parseInstant("2026-10-04T12:00:00Z"))

        let detail = try ContractSamples.decode(TournamentDetail.self, from: Laurel.detail)
        #expect(detail.entries.count == 1 && detail.matches.isEmpty && detail.standings.isEmpty)
        #expect(detail.myEntry?.name == "Kreuzberg FC", "myEntryId names the caller's entry among the entries")

        let page = try ContractSamples.decode(Page<Tournament>.self, from: Laurel.list)
        #expect(page.items.map(\.id) == [Laurel.id] && page.nextCursor == nil)
    }

    /// `GET /api/groups/{id}` for a tournament's room: the fixed shape of plan 2.1, under the tournament's id.
    @Test func theRoomDecodesAsAGroupOfKindTournament() throws {
        let room = try ContractSamples.decode(SportGroup.self, from: Laurel.room)
        #expect(room.id == Laurel.id && room.kind == .tournament && room.isTournamentRoom && !room.isCommunity)
        #expect(room.name == "Kickers Cup" && room.visibility == .public && room.type == .football && room.ownerName == "Marta")
        #expect(room.memberCount == 3 && room.maxMembers == 21, "maxEntries * teamSize + 1")
        #expect(room.channelEpoch == 1 && !room.membersCanCreateEvents && !room.membersCanInvite)
        #expect(room.description == nil && room.counterpart == nil && room.lastMessageId == nil && room.lastMessageAt == nil)
        #expect(room.role == .owner && !room.hasUnread && room.createdAt == APIJSONCoding.parseInstant("2026-09-25T10:00:00Z"))
    }

    @Test func aReportedMatchAndAScheduledMatchDecode() throws {
        let reported = try ContractSamples.decode(TournamentMatch.self, from: Laurel.match)
        #expect(reported.id == "r01p002" && reported.tournamentId == Laurel.id && reported.round == 1 && reported.position == 2)
        #expect(reported.entryAId == Laurel.seeds[3] && reported.entryBId == Laurel.seeds[4] && reported.hasBothSides)
        #expect(reported.status == .reported && reported.scoreA == 2 && reported.scoreB == 3 && !reported.isDisputed)
        #expect(reported.reportedBy == "sub-5" && reported.reportedAt == APIJSONCoding.parseInstant("2026-10-18T12:00:00Z"))
        #expect(reported.winnerEntryId == nil && reported.confirmedBy == nil && reported.confirmedAt == nil)
        #expect(reported.scheduledAt == nil && reported.location == nil)
        #expect(reported.nextMatchId == "r02p001" && reported.nextSlot == .b)
        #expect(reported.isReadyForResult && !reported.isOpenDispute)

        let scheduled = try ContractSamples.decode(TournamentMatch.self, from: Laurel.scheduledMatch)
        #expect(scheduled.status == .scheduled && scheduled.scheduledAt == APIJSONCoding.parseInstant("2026-10-18T12:00:00Z"))
        #expect(scheduled.location == Laurel.feld && scheduled.scoreA == nil && scheduled.scoreB == nil)
        #expect(scheduled.reportedBy == nil)
    }

    @Test func theStandingDecodes() throws {
        let standing = try ContractSamples.decode(TournamentStanding.self, from: Laurel.standing)
        #expect(standing.entryId == Laurel.seeds[0] && standing.rank == 1 && standing.played == 2)
        #expect(standing.won == 1 && standing.drawn == 1 && standing.lost == 0)
        #expect(standing.scored == 5 && standing.conceded == 3 && standing.points == 4 && standing.scoreDifference == 2)
    }

    /// The started five-entry bracket: Laurel's draw is the one `TournamentSchedule` draws from the same seeds, match
    /// for match, apart from the second match's report.
    @Test func theStartedDetailIsTheSharedDraw() throws {
        let detail = try ContractSamples.decode(TournamentDetail.self, from: Laurel.startedDetail)
        let tournament = detail.tournament
        #expect(tournament.status == .inProgress && tournament.type == .tableTennis && tournament.teamSize == 1)
        #expect(tournament.description == nil && tournament.group == nil && tournament.registrationClosesAt == nil)
        #expect(tournament.startedAt == APIJSONCoding.parseInstant("2026-10-18T10:00:00Z"))
        #expect(tournament.updatedAt == tournament.startedAt)
        #expect(tournament.myEntryId == Laurel.seeds[0] && detail.myEntry?.name == "Player 1")
        #expect(detail.entries.map(\.seed) == [1, 2, 3, 4, 5] && detail.entries.map(\.id) == Laurel.seeds)
        #expect(detail.standings.isEmpty, "a bracket has no table")

        let drawn = TournamentSchedule.pairings(format: .singleElimination, seeds: Laurel.seeds)
            .map { TournamentMatch(pairing: $0, tournamentId: Laurel.id) }
        #expect(detail.matches.filter { $0.id != "r01p002" } == drawn.filter { $0.id != "r01p002" })
        let bye = try #require(detail.match(id: "r01p001"))
        #expect(bye.status == .bye && bye.winnerEntryId == Laurel.seeds[0] && bye.entryBId == nil && bye.nextSlot == .a)
        let final = try #require(detail.match(id: "r03p001"))
        #expect(!final.hasBothSides && final.nextMatchId == nil && final.nextSlot == nil && !final.isDecided)
        #expect(BracketLayout.columns(of: detail.matches).map(\.count) == [4, 2, 1])
    }

    @Test func theRoundRobinDetailCarriesItsTable() throws {
        let league = try ContractSamples.decode(TournamentDetail.self, from: Laurel.league)
        #expect(league.tournament.format == .roundRobin && league.tournament.allowsDraws && league.tournament.permitsDraws)
        #expect(league.matches.isEmpty && league.standings.map(\.entryId) == [Laurel.seeds[0]])
    }

    /// The four system rows as `MessageResponse` writes them (`@JsonInclude(NON_NULL)`, the two ids last): no
    /// `attachments` key on a system row, `text` only where the server renders one.
    @Test func theSystemRowsDecode() throws {
        let started = try ContractSamples.decode(ChatMessage.self, from: Laurel.tournamentStartedRow)
        #expect(started.kind == .tournamentStarted && started.isSystem && started.text == nil && started.attachments.isEmpty)
        #expect(started.tournamentId == Laurel.id && started.matchId == nil && started.clientMessageId == nil)
        let result = try ContractSamples.decode(ChatMessage.self, from: Laurel.matchResultRow)
        #expect(result.kind == .matchResult && result.text == "Kreuzberg FC 3–1 Riverside Rovers")
        #expect(result.matchId == "r01p002")
        let walkover = try ContractSamples.decode(ChatMessage.self, from: Laurel.walkoverRow)
        #expect(walkover.kind == .matchResult && walkover.text == "Kreuzberg FC wins by walkover")
        let disputed = try ContractSamples.decode(ChatMessage.self, from: Laurel.matchDisputedRow)
        #expect(disputed.kind == .matchDisputed && disputed.text == "Kreuzberg FC – Riverside Rovers")
        #expect(disputed.matchId == "r01p002")
        let completed = try ContractSamples.decode(ChatMessage.self, from: Laurel.tournamentCompletedRow)
        #expect(completed.kind == .tournamentCompleted && completed.text == "Kreuzberg FC" && completed.matchId == nil)
    }
}

/// The literals of Laurel's controller tests, character for character where they are literals there, and the same
/// builders where Laurel assembles them (`detailJson`, `entriesJson`).
enum LaurelTournamentJSON {
    static let id = "7c9e6679-7425-40de-944b-e07fc1f90ae7"
    static let entryID = "01K6QZ3F8X2M4N6P8R0T2V4W6Y"
    static let seeds = ["01K6QZ3F8X2M4N6P8R0T2V4W61", "01K6QZ3F8X2M4N6P8R0T2V4W62", "01K6QZ3F8X2M4N6P8R0T2V4W63",
                        "01K6QZ3F8X2M4N6P8R0T2V4W64", "01K6QZ3F8X2M4N6P8R0T2V4W65"]
    static let feld = EventLocation(name: "Tempelhofer Feld", coordinate: Coordinate(latitude: 52.4731, longitude: 13.4039))

    /// `TournamentControllerIt.TOURNAMENT_JSON`.
    static let tournament = """
    {"id":"7c9e6679-7425-40de-944b-e07fc1f90ae7","name":"Kickers Cup",
     "description":"Four teams, one Sunday.","type":"football","format":"single_elimination",
     "status":"registration","visibility":"public","teamSize":5,"maxEntries":4,"entryCount":1,
     "allowsDraws":true,"startsAt":"2026-10-18T10:00:00Z",
     "registrationClosesAt":"2026-10-17T10:00:00Z",
     "location":{"name":"Tempelhofer Feld","coordinate":{"latitude":52.4731,"longitude":13.4039}},
     "organizerUserId":"sub-1","organizerName":"Marta",
     "group":{"id":"g1","name":"Kreuzberg Kickers","visibility":"public","isDeleted":false},
     "channelEpoch":1,"myEntryId":"01K6QZ3F8X2M4N6P8R0T2V4W6Y",
     "createdAt":"2026-10-04T12:00:00Z"}
    """
    /// `TournamentControllerIt.ENTRY_JSON`.
    static let entry = """
    {"id":"01K6QZ3F8X2M4N6P8R0T2V4W6Y","tournamentId":"7c9e6679-7425-40de-944b-e07fc1f90ae7",
     "name":"Kreuzberg FC","captainUserId":"sub-1",
     "members":[{"userId":"sub-1","displayName":"Marta"},
                {"userId":"sub-2","displayName":"Jonas"}],
     "seed":1,"status":"registered","createdAt":"2026-10-04T12:00:00Z"}
    """
    /// `TournamentControllerIt.DETAIL_JSON` and the `{items}` of the list routes.
    static let detail = #"{"tournament":\#(tournament),"entries":[\#(entry)],"matches":[],"standings":[]}"#
    static let list = #"{"items":[\#(tournament)]}"#
    /// `GroupControllerIt.tournamentRoom_hasTheFixedShape_andRefusesGroupWrites`.
    static let room = """
    {"id":"7c9e6679-7425-40de-944b-e07fc1f90ae7","name":"Kickers Cup",
     "visibility":"public","type":"football","ownerName":"Marta","memberCount":3,
     "maxMembers":21,"channelEpoch":1,"membersCanCreateEvents":false,
     "membersCanInvite":false,"createdAt":"2026-09-25T10:00:00Z",
     "membership":{"role":"owner","joinedAt":"2026-09-25T10:00:00Z","hasUnread":false},
     "kind":"tournament"}
    """
    /// `TournamentMatchControllerIt.MATCH_JSON`: the reported second match of the five-entry draw.
    static let match = """
    {"id":"r01p002","tournamentId":"7c9e6679-7425-40de-944b-e07fc1f90ae7","round":1,
     "position":2,"entryAId":"01K6QZ3F8X2M4N6P8R0T2V4W64","entryBId":"01K6QZ3F8X2M4N6P8R0T2V4W65",
     "status":"reported","scoreA":2,"scoreB":3,"isDisputed":false,"reportedBy":"sub-5",
     "reportedAt":"2026-10-18T12:00:00Z","nextMatchId":"r02p001","nextSlot":"b"}
    """
    /// `TournamentMatchControllerIt.STANDING_JSON`.
    static let standing = """
    {"entryId":"01K6QZ3F8X2M4N6P8R0T2V4W61","rank":1,"played":2,"won":1,"drawn":1,"lost":0,
     "scored":5,"conceded":3,"points":4}
    """
    /// `TournamentMatchControllerIt.SCHEDULED_JSON`.
    static let scheduledMatch = """
    {"id":"r01p002","tournamentId":"7c9e6679-7425-40de-944b-e07fc1f90ae7","round":1,
     "position":2,"entryAId":"01K6QZ3F8X2M4N6P8R0T2V4W64","entryBId":"01K6QZ3F8X2M4N6P8R0T2V4W65",
     "status":"scheduled","isDisputed":false,"scheduledAt":"2026-10-18T12:00:00Z",
     "location":{"name":"Tempelhofer Feld","coordinate":{"latitude":52.4731,"longitude":13.4039}},
     "nextMatchId":"r02p001","nextSlot":"b"}
    """
    /// `TournamentMatchControllerIt.MATCHES_JSON`: the five-entry single elimination right after its start.
    static let matches = """
    [{"id":"r01p001","tournamentId":"7c9e6679-7425-40de-944b-e07fc1f90ae7","round":1,
      "position":1,"entryAId":"01K6QZ3F8X2M4N6P8R0T2V4W61","status":"bye",
      "winnerEntryId":"01K6QZ3F8X2M4N6P8R0T2V4W61","isDisputed":false,"nextMatchId":"r02p001",
      "nextSlot":"a"},
    \(match)
    ,{"id":"r01p003","tournamentId":"7c9e6679-7425-40de-944b-e07fc1f90ae7","round":1,
      "position":3,"entryAId":"01K6QZ3F8X2M4N6P8R0T2V4W62","status":"bye",
      "winnerEntryId":"01K6QZ3F8X2M4N6P8R0T2V4W62","isDisputed":false,"nextMatchId":"r02p002",
      "nextSlot":"a"},
     {"id":"r01p004","tournamentId":"7c9e6679-7425-40de-944b-e07fc1f90ae7","round":1,
      "position":4,"entryAId":"01K6QZ3F8X2M4N6P8R0T2V4W63","status":"bye",
      "winnerEntryId":"01K6QZ3F8X2M4N6P8R0T2V4W63","isDisputed":false,"nextMatchId":"r02p002",
      "nextSlot":"b"},
     {"id":"r02p001","tournamentId":"7c9e6679-7425-40de-944b-e07fc1f90ae7","round":2,
      "position":1,"entryAId":"01K6QZ3F8X2M4N6P8R0T2V4W61","status":"pending","isDisputed":false,
      "nextMatchId":"r03p001","nextSlot":"a"},
     {"id":"r02p002","tournamentId":"7c9e6679-7425-40de-944b-e07fc1f90ae7","round":2,
      "position":2,"entryAId":"01K6QZ3F8X2M4N6P8R0T2V4W62",
      "entryBId":"01K6QZ3F8X2M4N6P8R0T2V4W63","status":"pending","isDisputed":false,
      "nextMatchId":"r03p001","nextSlot":"b"},
     {"id":"r03p001","tournamentId":"7c9e6679-7425-40de-944b-e07fc1f90ae7","round":3,
      "position":1,"status":"pending","isDisputed":false}]
    """
    /// `detailJson(MATCHES_JSON, "[]")`: the started bracket, and `leagueJson()`: the round robin with its table.
    static let startedDetail = startedDetail(matches: matches, standings: "[]")
    static let league = startedDetail(matches: "[]", standings: "[\(standing)]")
        .replacingOccurrences(of: #""format":"single_elimination""#, with: #""format":"round_robin""#)
        .replacingOccurrences(of: #""allowsDraws":false"#, with: #""allowsDraws":true"#)

    /// A system row as `MessageResponse` writes one: `@JsonInclude(NON_NULL)`, `tournamentId` and `matchId` last, no
    /// `clientMessageId`, no `attachments`, `text` only where the server rendered one (`MatchSides`' wording).
    static let tournamentStartedRow = systemRow(id: "70", kind: "tournament_started", text: nil, matchID: nil)
    static let matchResultRow = systemRow(id: "71",
                                          kind: "match_result",
                                          text: "Kreuzberg FC 3–1 Riverside Rovers",
                                          matchID: "r01p002")
    static let walkoverRow = systemRow(id: "72", kind: "match_result", text: "Kreuzberg FC wins by walkover", matchID: "r01p002")
    static let matchDisputedRow = systemRow(id: "73",
                                            kind: "match_disputed",
                                            text: "Kreuzberg FC – Riverside Rovers",
                                            matchID: "r01p002")
    static let tournamentCompletedRow = systemRow(id: "74", kind: "tournament_completed", text: "Kreuzberg FC", matchID: nil)

    /// `TournamentMatchControllerIt.entriesJson()`: five players, "Player N" by "sub-N", seeded in order.
    private static let entries = seeds.enumerated().map { index, seed in
        let number = index + 1
        return #"{"id":"\#(seed)","tournamentId":"\#(id)","name":"Player \#(number)","captainUserId":"sub-\#(number)","# +
            #""members":[{"userId":"sub-\#(number)","displayName":"Player \#(number)"}],"seed":\#(number),"# +
            #""status":"registered","createdAt":"2026-10-04T12:00:00Z"}"#
    }.joined(separator: ",")

    /// `TournamentMatchControllerIt.detailJson(matches, standings)`.
    private static func startedDetail(matches: String, standings: String) -> String {
        #"""
        {"tournament":{"id":"\#(id)","name":"Tuesday Table Tennis","type":"table_tennis","format":"single_elimination",
         "status":"in_progress","visibility":"public","teamSize":1,"maxEntries":8,"entryCount":5,"allowsDraws":false,
         "startsAt":"2026-10-18T10:00:00Z",
         "location":{"name":"Tempelhofer Feld","coordinate":{"latitude":52.4731,"longitude":13.4039}},
         "organizerUserId":"sub-1","organizerName":"Marta","channelEpoch":1,"myEntryId":"\#(seeds[0])",
         "startedAt":"2026-10-18T10:00:00Z","createdAt":"2026-10-04T12:00:00Z","updatedAt":"2026-10-18T10:00:00Z"},
         "entries":[\#(entries)],"matches":\#(matches),"standings":\#(standings)}
        """#
    }

    private static func systemRow(id suffix: String, kind: String, text: String?, matchID: String?) -> String {
        let textField = text.map { #","text":"\#($0)""# } ?? ""
        let matchField = matchID.map { #","matchId":"\#($0)""# } ?? ""
        return #"{"id":"01K6QZ3F8X2M4N6P8R0T2V4W\#(suffix)","groupId":"\#(id)","senderUserId":"sub-1","senderName":"Marta","# +
            #""kind":"\#(kind)"\#(textField),"sentAt":"2026-10-18T12:00:00Z","isDeleted":false,"# +
            #""tournamentId":"\#(id)"\#(matchField)}"#
    }
}
