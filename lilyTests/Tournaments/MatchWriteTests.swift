import Foundation
import Testing
@testable import lily

/// A write counts as landed only when the match fetched back shows it by the caller's hand.
struct MatchWriteTests {
    private let noon = Date(timeIntervalSince1970: 1_800_014_400)
    private let match = TournamentMatch(id: "r01p001",
                                        tournamentId: "t",
                                        round: 1,
                                        position: 1,
                                        entryAId: "e1",
                                        entryBId: "e2")

    @Test func aResultLandedWhenTheCallersScoresStand() {
        let write = MatchWrite.result(scoreA: 3, scoreB: 1)
        let myReport = match.reporting(3, 1, by: "me", at: noon)
        #expect(write.landed(on: myReport, callerID: "me"))
        #expect(!MatchWrite.result(scoreA: 3, scoreB: 2).landed(on: myReport, callerID: "me"), "another score")

        let theirReport = match.reporting(3, 1, by: "other", at: noon)
        #expect(!write.landed(on: theirReport, callerID: "me"), "my same score would have confirmed their report")
        #expect(write.landed(on: myReport.confirming(by: "other", at: noon), callerID: "me"), "confirmed meanwhile")
        #expect(write.landed(on: match.recording(3, 1, by: "me", at: noon), callerID: "me"), "the organiser's record")
        #expect(!write.landed(on: match, callerID: "me"), "nothing written")
    }

    @Test func aConfirmationLandedOnlyByTheCallersHand() {
        let theirReport = match.reporting(3, 1, by: "other", at: noon)
        #expect(MatchWrite.confirmation.landed(on: theirReport.confirming(by: "me", at: noon), callerID: "me"))

        let confirmedByThem = match.reporting(3, 1, by: "me", at: noon).confirming(by: "other", at: noon)
        #expect(!MatchWrite.confirmation.landed(on: confirmedByThem, callerID: "me"), "the other side confirmed")
        #expect(!MatchWrite.confirmation.landed(on: theirReport, callerID: "me"), "still reported")
    }

    @Test func aDisputeLandedWhenTheMatchIsOpenAndFlagged() {
        let disputed = match.reporting(3, 1, by: "other", at: noon).disputing()
        #expect(MatchWrite.dispute.landed(on: disputed, callerID: "me"))

        let confirmed = match.reporting(3, 1, by: "other", at: noon).confirming(by: "me", at: noon)
        #expect(!MatchWrite.dispute.landed(on: confirmed, callerID: "me"), "confirmed instead")
        #expect(!MatchWrite.dispute.landed(on: disputed.recording(2, 1, by: "org", at: noon), callerID: "me"),
                "decided since; the flag alone is history")
        #expect(!MatchWrite.dispute.landed(on: match, callerID: "me"), "open but never disputed")
    }

    @Test func aWalkoverLandedForThatWinnerByTheCaller() {
        let walkover = match.walkover(winnerEntryId: "e1", by: "me", at: noon)
        #expect(MatchWrite.walkover(winnerEntryID: "e1").landed(on: walkover, callerID: "me"))
        #expect(!MatchWrite.walkover(winnerEntryID: "e2").landed(on: walkover, callerID: "me"), "the other side")

        let theirs = match.walkover(winnerEntryId: "e1", by: "other", at: noon)
        #expect(!MatchWrite.walkover(winnerEntryID: "e1").landed(on: theirs, callerID: "me"), "not the caller's hand")
    }

    @Test func aScheduleLandedWhenTimeAndPlaceAgree() {
        let pitch = EventLocation(name: "Pitch 2", coordinate: Coordinate(latitude: 52.49, longitude: 13.43))
        let schedule = MatchSchedule(scheduledAt: noon, location: pitch)
        let scheduled = match.scheduling(schedule)
        #expect(MatchWrite.schedule(schedule).landed(on: scheduled, callerID: "me"))

        let later = MatchSchedule(scheduledAt: noon.addingTimeInterval(3_600), location: pitch)
        #expect(!MatchWrite.schedule(later).landed(on: scheduled, callerID: "me"), "another time")
        let elsewhere = MatchSchedule(scheduledAt: noon, location: EventLocation(name: "Hall", coordinate: pitch.coordinate))
        #expect(!MatchWrite.schedule(elsewhere).landed(on: scheduled, callerID: "me"), "another place")

        #expect(MatchWrite.schedule(MatchSchedule()).landed(on: match, callerID: "me"), "cleared on a bare match")
        #expect(!MatchWrite.schedule(MatchSchedule()).landed(on: scheduled, callerID: "me"), "asked clear, still set")
    }
}
