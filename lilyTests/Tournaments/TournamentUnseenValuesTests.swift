import Foundation
import Testing
@testable import lily

/// The tournament wire enums under a value this build does not know: the page, the detail, the match and the entry
/// still decode, nothing is offered for the unknown state, and chips and cells show the raw name.
struct TournamentUnseenValuesTests {
    /// A status a newer backend added decodes inside a page; the tournament is neither listed, startable nor over, and
    /// nothing is offered for it. Its chip shows the raw name, and it goes back out as it came.
    @Test func aTournamentWithAnUnseenStatusDecodesInAPageAndOffersNothing() throws {
        let json = ContractSamples.tournamentList
            .replacingOccurrences(of: #""status":"registration""#, with: #""status":"paused""#)
        let page = try ContractSamples.decode(Page<Tournament>.self, from: json)
        let tournament = try #require(page.items.first)

        #expect(tournament.status == .unknown("paused") && tournament.status.wireName == "paused" && tournament.status.isUnknown)
        #expect(tournament.status.displayName == "paused")
        #expect(!tournament.isListed && !tournament.canStart && !tournament.status.isOver)
        #expect(!tournament.isRegistrationOpen(now: .now))
        let organiser = TournamentPermissions(tournament: tournament, userID: "u-1", now: .now, chatEnabled: true)
        #expect(!organiser.showsStart && !organiser.canRemoveEntries)
        let match = try ContractSamples.decode(TournamentMatch.self, from: ContractSamples.match)
        let detail = TournamentDetail(tournament: tournament, entries: [], matches: [match])
        #expect(MatchActions(detail: detail, match: match, userID: "u-1").isEmpty)
        let encoded = try #require(String(bytes: try APIJSONCoding.makeEncoder().encode(tournament), encoding: .utf8))
        #expect(encoded.contains(#""status":"paused""#))
    }

    @Test func aMatchWithAnUnseenStatusAndSlotDecodesAndStaysUndecided() throws {
        let json = ContractSamples.match
            .replacingOccurrences(of: #""status":"pending""#, with: #""status":"forfeit""#)
            .replacingOccurrences(of: #""nextSlot":"b""#, with: #""nextSlot":"c""#)
        let match = try ContractSamples.decode(TournamentMatch.self, from: json)

        #expect(match.status == .unknown("forfeit") && match.nextSlot == .unknown("c"))
        #expect(!match.isDecided && !match.status.isOpen && !match.isReadyForResult)
        #expect(AppBranding.Tournaments.Match.status(.unknown("forfeit")) == "forfeit")
        #expect(match.placing("e", in: .unknown("c")) == match, "an unknown slot places nobody")
        let detail = TournamentDetail(tournament: .fixture(format: .singleElimination, status: .inProgress), matches: [match])
        let settled = detail.settling(match, at: .now)
        #expect(settled.tournament.status == .inProgress && settled.tournament.winnerEntryId == nil, "nothing completes")
    }

    @Test func anEntryWithAnUnseenStatusIsNotRegistered() throws {
        let json = ContractSamples.entry.replacingOccurrences(of: #""status":"registered""#, with: #""status":"banned""#)
        let entry = try ContractSamples.decode(TournamentEntry.self, from: json)

        #expect(entry.status == .unknown("banned") && !entry.isRegistered)
        #expect(TournamentDetail(tournament: .fixture(), entries: [entry]).registeredEntries.isEmpty)
    }

    /// A format a newer backend added draws neither a bracket nor a table, takes the widest entries range and shows its
    /// raw name; the room's start row falls back to the generic line.
    @Test func aTournamentOfAnUnseenFormatDecodesAndDrawsPlainly() throws {
        let json = ContractSamples.tournament
            .replacingOccurrences(of: #""format":"single_elimination""#, with: #""format":"swiss""#)
        let tournament = try ContractSamples.decode(Tournament.self, from: json)

        #expect(tournament.format == .unknown("swiss") && tournament.format.displayName == "swiss")
        #expect(!tournament.format.drawsBracket)
        #expect(tournament.format.entriesRange == 2...64 && tournament.format.minimumEntriesToStart == 2)
        #expect(AppBranding.Chat.tournamentStarted(format: .unknown("swiss")) == "The tournament started")
        #expect(BracketLayout.roundTitle(round: 1, of: 3, format: .unknown("swiss")) == "Round 1")
        #expect(TournamentSchedule.pairings(format: .unknown("swiss"), seeds: ["a", "b"]).isEmpty)
        let entries = [TournamentEntry.fixture(id: "e1", seed: 1), TournamentEntry.fixture(id: "e2", seed: 2)]
        let started = TournamentDetail(tournament: tournament, entries: entries).starting(at: .now)
        #expect(started.matches.isEmpty && started.standings.isEmpty)
        let decided = TournamentMatch(id: "r01p001",
                                      tournamentId: "t",
                                      round: 1,
                                      position: 1,
                                      entryAId: "e1",
                                      entryBId: "e2",
                                      status: .confirmed,
                                      scoreA: 3,
                                      scoreB: 1,
                                      winnerEntryId: "e1")
        let playing = TournamentDetail(tournament: .fixture(format: .unknown("swiss"), status: .inProgress),
                                       entries: entries,
                                       matches: [decided])
        #expect(playing.settling(decided, at: .now).tournament.status == .inProgress, "every match decided names no champion")
    }
}
