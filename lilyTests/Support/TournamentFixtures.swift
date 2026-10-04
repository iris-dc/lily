import Foundation
@testable import lily

extension Tournament {
    /// A public individual tournament in registration, organised by Marta, with every optional detail absent unless
    /// given, so tests state only what they test.
    static func fixture(id: String = "t",
                        name: String = "Tuesday Table Tennis",
                        type: EventType = .tableTennis,
                        format: TournamentFormat = .roundRobin,
                        status: TournamentStatus = .registration,
                        visibility: GroupVisibility = .public,
                        teamSize: Int = 1,
                        maxEntries: Int = 8,
                        entryCount: Int = 2,
                        allowsDraws: Bool = false,
                        startsAt: Date = Date(timeIntervalSince1970: 1_800_000_000),
                        registrationClosesAt: Date? = nil,
                        organizerUserId: String = "seed-marta",
                        organizerName: String = "Marta",
                        group: EventGroupRef? = nil,
                        myEntryId: String? = nil,
                        createdAt: Date = Date(timeIntervalSince1970: 1_700_000_000)) -> Tournament {
        Tournament(id: id,
                   name: name,
                   type: type,
                   format: format,
                   status: status,
                   visibility: visibility,
                   teamSize: teamSize,
                   maxEntries: maxEntries,
                   entryCount: entryCount,
                   allowsDraws: allowsDraws,
                   startsAt: startsAt,
                   registrationClosesAt: registrationClosesAt,
                   location: EventLocation(name: "Sports Hall", coordinate: AppConfig.Location.mockCenter),
                   organizerUserId: organizerUserId,
                   organizerName: organizerName,
                   group: group,
                   myEntryId: myEntryId,
                   createdAt: createdAt)
    }
}

extension TournamentEntry {
    /// One registered entry, a player alone unless given members.
    static func fixture(id: String = "01J9ENTRY00000000000000001",
                        tournamentId: String = "t",
                        name: String = "Marta",
                        captainUserId: String = "seed-marta",
                        members: [EntryMember]? = nil,
                        seed: Int = 1,
                        createdAt: Date = Date(timeIntervalSince1970: 1_700_000_100)) -> TournamentEntry {
        TournamentEntry(id: id,
                        tournamentId: tournamentId,
                        name: name,
                        captainUserId: captainUserId,
                        members: members ?? [EntryMember(userId: captainUserId, displayName: name)],
                        seed: seed,
                        createdAt: createdAt)
    }
}

extension TournamentDetail {
    static func fixture(tournament: Tournament = .fixture(),
                        entries: [TournamentEntry] = [.fixture()],
                        matches: [TournamentMatch] = [],
                        standings: [TournamentStanding] = []) -> TournamentDetail {
        TournamentDetail(tournament: tournament, entries: entries, matches: matches, standings: standings)
    }
}

extension TournamentDraft {
    /// A draft that passes validation: the required fields set, starting `defaultStartOffset` after `now`, at the demo
    /// centre unless told otherwise (`nil` exercises the missing-coordinate paths). The id is a lower-case UUID like a
    /// real draft's, so the bodies the contract tests assert are ones the backend accepts.
    static func fixture(now: Date = .now,
                        clientId: String = "3f2504e0-4f89-11d3-9a0c-0305e82c3303",
                        coordinate: Coordinate? = AppConfig.Location.mockCenter) -> TournamentDraft {
        let startsAt = now.addingTimeInterval(AppConfig.Tournaments.defaultStartOffset)
        var draft = TournamentDraft(startsAt: startsAt, clientId: clientId)
        draft.name = "Kickers Cup"
        draft.locationName = "Görlitzer Park pitch"
        draft.coordinate = coordinate
        return draft
    }
}

extension SportGroup {
    /// A tournament's room as the backend shapes one: kind `tournament`, under the tournament's id, the organiser as
    /// owner (`role`), `maxEntries * teamSize + 1` seats, no group powers.
    static func tournamentRoomFixture(id: String = "t",
                                      name: String = "Tuesday Table Tennis",
                                      memberCount: Int = 6,
                                      maxMembers: Int = 9,
                                      role: MemberRole? = .member,
                                      lastMessageAt: Date? = nil) -> SportGroup {
        SportGroup(id: id,
                   name: name,
                   visibility: .public,
                   type: .tableTennis,
                   ownerName: "Marta",
                   memberCount: memberCount,
                   maxMembers: maxMembers,
                   membersCanCreateEvents: false,
                   membersCanInvite: false,
                   lastMessageAt: lastMessageAt,
                   createdAt: Date(timeIntervalSince1970: 1_700_000_000),
                   membership: role.map { GroupMembership(role: $0, joinedAt: Date(timeIntervalSince1970: 1_700_000_000)) },
                   kind: .tournament)
    }
}

/// The tournament JSON exactly as the contract shows it (tournaments plan, section 2.1; Laurel's strict-JSON tests are
/// compared with these): optionals omitted, never null; the place and the group ref in the event's shapes.
extension ContractSamples {
    static let tournament = """
    {"id":"9c1f2e3d-4b5a-4c6d-8e7f-0a1b2c3d4e5f","name":"Kickers Cup","description":"Eight teams, one evening",\
    "type":"football","format":"single_elimination","status":"registration","visibility":"public","teamSize":5,\
    "maxEntries":8,"entryCount":4,"allowsDraws":false,"startsAt":"2026-10-18T10:00:00Z",\
    "registrationClosesAt":"2026-10-16T10:00:00Z",\
    "location":{"name":"Görlitzer Park pitch","coordinate":{"latitude":52.496,"longitude":13.437}},\
    "organizerUserId":"u-1","organizerName":"Apple Tester",\
    "group":{"id":"7b1c2d3e-4f50-4a6b-8c9d-0e1f2a3b4c5d","name":"Kreuzberg Kickers","visibility":"public","isDeleted":false},\
    "channelEpoch":1,"createdAt":"2026-10-04T10:00:00Z"}
    """
    /// A standalone round robin under way, with the caller entered, as `GET /api/tournaments/{id}` answers a player.
    static let startedTournament = """
    {"id":"0d9e8f7a-6b5c-4d3e-9f2a-1b0c9d8e7f6a","name":"Tuesday Table Tennis","type":"table_tennis","format":"round_robin",\
    "status":"in_progress","visibility":"public","teamSize":1,"maxEntries":8,"entryCount":6,"allowsDraws":false,\
    "startsAt":"2026-10-02T18:00:00Z",\
    "location":{"name":"Prenzlauer Berg Sports Hall","coordinate":{"latitude":52.54,"longitude":13.41}},\
    "organizerUserId":"seed-marta","organizerName":"Marta","channelEpoch":2,"myEntryId":"01J9ENTRY0000000000000003",\
    "startedAt":"2026-10-02T18:00:00Z","createdAt":"2026-09-20T10:00:00Z","updatedAt":"2026-10-02T18:00:00Z"}
    """
    static let entry = """
    {"id":"01J9ENTRY0000000000000001","tournamentId":"9c1f2e3d-4b5a-4c6d-8e7f-0a1b2c3d4e5f","name":"Görli Giants",\
    "captainUserId":"seed-marta","members":[{"userId":"seed-marta","displayName":"Marta"},\
    {"userId":"seed-jonas","displayName":"Jonas"}],"seed":1,"status":"registered","createdAt":"2026-10-05T10:00:00Z"}
    """
    /// A first-round match of a bracket, undecided, pointing at the semi-final it feeds.
    static let match = """
    {"id":"r01p002","tournamentId":"9c1f2e3d-4b5a-4c6d-8e7f-0a1b2c3d4e5f","round":1,"position":2,\
    "entryAId":"01J9ENTRY0000000000000004","entryBId":"01J9ENTRY0000000000000005","status":"pending","isDisputed":false,\
    "nextMatchId":"r02p001","nextSlot":"b"}
    """
    /// A confirmed round-robin result with a time and a place.
    static let confirmedMatch = """
    {"id":"r01p001","tournamentId":"0d9e8f7a-6b5c-4d3e-9f2a-1b0c9d8e7f6a","round":1,"position":1,\
    "entryAId":"01J9ENTRY0000000000000001","entryBId":"01J9ENTRY0000000000000006","status":"confirmed","scoreA":3,\
    "scoreB":1,"winnerEntryId":"01J9ENTRY0000000000000001","isDisputed":false,"scheduledAt":"2026-10-07T18:00:00Z",\
    "location":{"name":"Table two","coordinate":{"latitude":52.54,"longitude":13.41}},"reportedBy":"seed-marta",\
    "reportedAt":"2026-10-07T20:00:00Z","confirmedBy":"seed-noor","confirmedAt":"2026-10-07T20:05:00Z"}
    """
    static let standing = """
    {"entryId":"01J9ENTRY0000000000000001","rank":1,"played":1,"won":1,"drawn":0,"lost":0,"scored":3,"conceded":1,"points":3}
    """
    static let tournamentDetail = #"{"tournament":\#(tournament),"entries":[\#(entry)],"matches":[],"standings":[]}"#
    static let startedTournamentDetail = """
    {"tournament":\(startedTournament),"entries":[\(entry)],"matches":[\(confirmedMatch)],"standings":[\(standing)]}
    """
    static let tournamentList = #"{"items":[\#(tournament)]}"#
    /// The room of a tournament, as `GET /api/groups?scope=mine` lists it: kind `tournament`, the fixed fields of 2.1.
    static let tournamentRoom = """
    {"id":"9c1f2e3d-4b5a-4c6d-8e7f-0a1b2c3d4e5f","name":"Kickers Cup","visibility":"public","type":"football",\
    "ownerName":"Apple Tester","memberCount":12,"maxMembers":41,"channelEpoch":1,"membersCanCreateEvents":false,\
    "membersCanInvite":false,"createdAt":"2026-10-04T10:00:00Z",\
    "membership":{"role":"owner","joinedAt":"2026-10-04T10:00:00Z","hasUnread":false},"kind":"tournament"}
    """
}
