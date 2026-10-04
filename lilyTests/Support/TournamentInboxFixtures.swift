import Foundation
@testable import lily

extension InboxItem {
    /// A pending invite into Noor's individual padel round robin; ids given by tests sort as ULIDs do.
    static func tournamentInvite(id: String = "01J9INBOX00000000000000004",
                                 tournamentID: String = "t1",
                                 tournamentName: String = "Padel Open",
                                 type: EventType = .padel,
                                 format: TournamentFormat = .roundRobin,
                                 teamSize: Int = 1,
                                 inviterName: String = "Noor",
                                 status: InviteStatus = .pending,
                                 createdAt: Date = Date(timeIntervalSince1970: 1_800_000_000),
                                 expiresAt: Date = Date(timeIntervalSince1970: 1_801_209_600),
                                 respondedAt: Date? = nil) -> InboxItem {
        InboxItem(id: id,
                  kind: .tournamentInvite,
                  createdAt: createdAt,
                  tournamentInvite: TournamentInvitePayload(tournamentId: tournamentID,
                                                            tournamentName: tournamentName,
                                                            type: type,
                                                            format: format,
                                                            teamSize: teamSize,
                                                            inviterUserId: "u-\(inviterName.lowercased())",
                                                            inviterName: inviterName,
                                                            status: status,
                                                            expiresAt: expiresAt,
                                                            respondedAt: respondedAt))
    }

    /// A reminder for the caller's match an hour ahead of the fixture clock.
    static func matchReminder(id: String = "01J9INBOX00000000000000005",
                              tournamentID: String = "t1",
                              tournamentName: String = "Tuesday Table Tennis",
                              matchID: String = "r03p002",
                              opponentName: String = "Dev",
                              scheduledAt: Date = Date(timeIntervalSince1970: 1_800_003_600),
                              locationName: String? = "Prenzlauer Berg Sports Hall",
                              createdAt: Date = Date(timeIntervalSince1970: 1_800_000_000)) -> InboxItem {
        InboxItem(id: id,
                  kind: .matchReminder,
                  createdAt: createdAt,
                  matchReminder: MatchReminderPayload(tournamentId: tournamentID,
                                                      tournamentName: tournamentName,
                                                      matchId: matchID,
                                                      opponentName: opponentName,
                                                      scheduledAt: scheduledAt,
                                                      locationName: locationName))
    }
}

/// Laurel's strict-JSON literals for the tournament inbox items, the accept answers, the invite routes and the room
/// events, verbatim from B3's hand-over (`InboxControllerIt`, `TournamentInviteControllerIt`, the realtime publisher);
/// Lily decodes them as they are, so a key that moves on either side fails a test.
enum LaurelTournamentInboxJSON {
    static let tournamentID = "7c9e6679-7425-40de-944b-e07fc1f90ae7"
    static let inviteItemID = "01ARYZ6S41TSV4RRFFQ69G5FAX"
    static let reminderItemID = "01ARYZ6S41TSV4RRFFQ69G5FAY"
    static let tournamentInvite = """
    {"id":"\(inviteItemID)","kind":"tournament_invite","createdAt":"2026-09-25T10:00:00Z",\
    "tournamentInvite":{"tournamentId":"\(tournamentID)","tournamentName":"Kickers Cup","type":"football",\
    "format":"single_elimination","teamSize":5,"inviterUserId":"sub-2","inviterName":"Noor","status":"pending",\
    "expiresAt":"2026-10-09T10:00:00Z"}}
    """
    static let matchReminder = """
    {"id":"\(reminderItemID)","kind":"match_reminder","createdAt":"2026-09-25T10:00:00Z",\
    "matchReminder":{"tournamentId":"\(tournamentID)","tournamentName":"Kickers Cup","matchId":"r01p002",\
    "opponentName":"Riverside Rovers","scheduledAt":"2026-10-18T12:00:00Z","locationName":"Tempelhofer Feld"}}
    """
    /// The same reminder for a match scheduled without a place.
    static let matchReminderWithoutPlace = matchReminder
        .replacingOccurrences(of: #","locationName":"Tempelhofer Feld""#, with: "")
    /// The invite item once accepted, as both accept answers carry it.
    static let acceptedTournamentInvite = tournamentInvite
        .replacingOccurrences(of: #""status":"pending""#, with: #""status":"accepted""#)
        .replacingOccurrences(of: #""expiresAt":"2026-10-09T10:00:00Z"}"#,
                              with: #""expiresAt":"2026-10-09T10:00:00Z","respondedAt":"2026-09-25T10:01:00Z"}"#)
    /// The tournament as `InviteAcceptedResponse` answers it; `myEntryId` is the accept's own entry.
    static let acceptedTournament = """
    {"id":"\(tournamentID)","name":"Kickers Cup","description":"Four teams, one Sunday.","type":"football",\
    "format":"single_elimination","status":"registration","visibility":"public","teamSize":5,"maxEntries":4,"entryCount":1,\
    "allowsDraws":true,"startsAt":"2026-10-18T10:00:00Z","registrationClosesAt":"2026-10-17T10:00:00Z",\
    "location":{"name":"Tempelhofer Feld","coordinate":{"latitude":52.4731,"longitude":13.4039}},\
    "organizerUserId":"sub-1","organizerName":"Marta",\
    "group":{"id":"g1","name":"Kreuzberg Kickers","visibility":"public","isDeleted":false},"channelEpoch":1,\
    "myEntryId":"01K6QZ3F8X2M4N6P8R0T2V4W6Y","createdAt":"2026-10-04T12:00:00Z"}
    """
    /// Individual tournament: the accept entered the caller. No `group` key.
    static let inviteAcceptedIndividual = #"{"item":\#(acceptedTournamentInvite),"tournament":\#(acceptedTournament)}"#
    /// Team tournament: the item flipped alone, no entry yet, so no `myEntryId`.
    static let inviteAcceptedTeam = """
    {"item":\(acceptedTournamentInvite),\
    "tournament":\(acceptedTournament.replacingOccurrences(of: #""myEntryId":"01K6QZ3F8X2M4N6P8R0T2V4W6Y","#, with: ""))}
    """
    /// `POST /api/tournaments/{id}/invites` -> 201.
    static let sentInvite = """
    {"id":"\(inviteItemID)","tournamentId":"\(tournamentID)","inviteeUserId":"sub-2","inviteeName":"Noor","status":"pending",\
    "createdAt":"2026-10-04T12:00:00Z","expiresAt":"2026-10-18T12:00:00Z"}
    """
    /// `GET /api/tournaments/{id}/invitees`: the group invitee shape, the room counting as a `group` source.
    static let invitees = """
    {"items":[{"userId":"sub-2","displayName":"Noor","via":"group","viaName":"Kickers Cup","isInvited":true},\
    {"userId":"sub-3","displayName":"Jonas","via":"event","viaName":"Sunset 5-a-side","isInvited":false}]}
    """
    static let tournamentChangedEnvelope = """
    {"type":"tournament_changed","tournamentId":"t1","status":"in_progress","entryCount":5,"channelEpoch":3,\
    "updatedAt":"2026-09-25T10:00:00Z"}
    """
    /// `updatedAt` is omitted when null.
    static let tournamentChangedEnvelopeWithoutUpdate = """
    {"type":"tournament_changed","tournamentId":"t1","status":"cancelled","entryCount":5,"channelEpoch":3}
    """
    static let matchUpdatedEnvelope = """
    {"type":"match_updated","match":{"id":"r01p002","tournamentId":"t1","round":1,"position":2,"entryAId":"e4","entryBId":"e5",\
    "status":"scheduled","isDisputed":false,"scheduledAt":"2026-09-25T10:00:00Z","nextMatchId":"r02p001","nextSlot":"b"}}
    """
    /// `inbox_item` on `users/<sub>`, carrying a tournament invite like any kind (`RealtimeEventTest`).
    static let inboxItemEnvelope = #"{"type":"inbox_item","item":\#(tournamentInvite)}"#
    /// `PUT .../matches/{matchId}/schedule` as `TournamentMatchControllerIt` sends it; an absent body clears.
    static let scheduleRequest = """
    {"scheduledAt":"2026-10-18T12:00:00Z","location":{"name":"Tempelhofer Feld",\
    "coordinate":{"latitude":52.4731,"longitude":13.4039}}}
    """
}
