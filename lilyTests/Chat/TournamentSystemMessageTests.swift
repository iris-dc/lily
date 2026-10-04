import Foundation
import Testing
@testable import lily

/// The tournament notes of a room (plan 2.4): their kinds on the wire, the ids they carry, and that the transcript
/// shows them like any system row.
struct TournamentSystemMessageTests {
    @Test func theTournamentKindsRoundTripThroughTheirWireNames() throws {
        let kinds: [MessageKind] = [.tournamentStarted, .matchResult, .matchDisputed, .tournamentCompleted]
        let json = try #require(String(bytes: try JSONEncoder().encode(kinds), encoding: .utf8))
        #expect(json == #"["tournament_started","match_result","match_disputed","tournament_completed"]"#)
        let decoded = try JSONDecoder().decode([MessageKind].self, from: Data(json.utf8))
        #expect(decoded == kinds)
        #expect(kinds.allSatisfy { $0.isTournamentNote })
        #expect(!MessageKind.eventCreated.isTournamentNote && !MessageKind.text.isTournamentNote)
    }

    @Test func aStartedNoteCarriesTheTournamentAndNoMatch() throws {
        let message = try ContractSamples.decode(ChatMessage.self, from: ContractSamples.tournamentStartedMessage)
        #expect(message.kind == .tournamentStarted && message.isSystem && message.text == nil)
        #expect(message.tournamentId == "0d9e8f7a-6b5c-4d3e-9f2a-1b0c9d8e7f6a")
        #expect(message.matchId == nil && message.eventId == nil)
    }

    @Test func aResultAndADisputeNameTheirMatchAndCarryTheServersText() throws {
        let result = try ContractSamples.decode(ChatMessage.self, from: ContractSamples.matchResultMessage)
        #expect(result.kind == .matchResult && result.text == "Marta 3–1 Noor" && result.matchId == "r01p001")
        let disputed = try ContractSamples.decode(ChatMessage.self, from: ContractSamples.matchDisputedMessage)
        #expect(disputed.kind == .matchDisputed && disputed.text == "Noor – Ayşe" && disputed.matchId == "r02p002")
        let completed = try ContractSamples.decode(ChatMessage.self, from: ContractSamples.tournamentCompletedMessage)
        #expect(completed.kind == .tournamentCompleted && completed.text == "Marta" && completed.matchId == nil)
    }

    /// The ids go back out as they came and survive a tombstone, like `eventId`; a plain message writes neither.
    @Test func theIdsEncodeAsTheyCameAndSurviveADelete() throws {
        let result = try ContractSamples.decode(ChatMessage.self, from: ContractSamples.matchResultMessage)
        let json = try #require(String(bytes: try APIJSONCoding.makeEncoder().encode(result), encoding: .utf8))
        #expect(json.contains(#""tournamentId":"0d9e8f7a-6b5c-4d3e-9f2a-1b0c9d8e7f6a""#))
        #expect(json.contains(#""matchId":"r01p001""#))
        #expect(try ContractSamples.decode(ChatMessage.self, from: json) == result)
        let deleted = result.markingDeleted()
        #expect(deleted.tournamentId == result.tournamentId && deleted.matchId == "r01p001" && deleted.text == nil)

        let plain = try ContractSamples.decode(ChatMessage.self, from: ContractSamples.message)
        let plainJSON = try #require(String(bytes: try APIJSONCoding.makeEncoder().encode(plain), encoding: .utf8))
        #expect(!plainJSON.contains("tournamentId") && !plainJSON.contains("matchId") && plain.tournamentId == nil)
    }

    @Test func theTimelineShowsTournamentNotesAsSystemRows() {
        let noon = Date(timeIntervalSince1970: 1_800_014_400)
        let rows = ChatTimeline.rows(ChatTimeline.Input(messages: [
            .fixture(id: "m1", sentAt: noon),
            .fixture(id: "m2", kind: .tournamentStarted, tournamentID: "t", sentAt: noon.addingTimeInterval(10)),
            .fixture(id: "m3", kind: .matchResult, tournamentID: "t", matchID: "r01p001", sentAt: noon.addingTimeInterval(20)),
        ], currentUserID: "u-1"))
        let systemIDs = rows.compactMap { if case .system(let message) = $0 { message.id } else { nil } }
        #expect(systemIDs == ["m2", "m3"] && rows.count == 4, "a day chip, a bubble and two notes")
    }
}
