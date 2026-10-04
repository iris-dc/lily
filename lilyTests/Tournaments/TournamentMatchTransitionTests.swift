import Foundation
import Testing
@testable import lily

/// A match's transitions as the backend's `MatchWrites` make them: who gets stamped, what a dispute and a walkover drop,
/// and that the dispute flag, once set, stays.
struct TournamentMatchTransitionTests {
    private let noon = Date(timeIntervalSince1970: 1_800_014_400)
    private let match = TournamentMatch(id: "r01p001",
                                        tournamentId: "t",
                                        round: 1,
                                        position: 1,
                                        entryAId: "e1",
                                        entryBId: "e2")

    @Test func aReportStampsTheReporterAndARecordStampsBoth() {
        let reported = match.reporting(3, 1, by: "u1", at: noon)
        #expect(reported.status == .reported && reported.scoreA == 3 && reported.scoreB == 1 && reported.winnerEntryId == nil)
        #expect(reported.reportedBy == "u1" && reported.reportedAt == noon && reported.confirmedBy == nil)
        #expect(reported.isReadyForResult && !reported.isDecided)

        let recorded = match.recording(3, 1, by: "org", at: noon)
        #expect(recorded.status == .confirmed && recorded.winnerEntryId == "e1" && recorded.isDecided)
        #expect(recorded.reportedBy == "org" && recorded.confirmedBy == "org" && recorded.confirmedAt == noon)
        #expect(match.recording(2, 2, by: "org", at: noon).winnerEntryId == nil, "a draw has no winner")
        #expect(match.recording(0, 1, by: "org", at: noon).winnerEntryId == "e2")
    }

    @Test func aConfirmationKeepsTheReporter() {
        let confirmed = match.reporting(3, 1, by: "u1", at: noon).confirming(by: "u2", at: noon.addingTimeInterval(60))
        #expect(confirmed.status == .confirmed && confirmed.winnerEntryId == "e1")
        #expect(confirmed.reportedBy == "u1" && confirmed.confirmedBy == "u2")
        #expect(match.confirming(by: "u2", at: noon) == match, "nothing to confirm without a score")
    }

    @Test func aDisputeReopensDropsTheReportAndKeepsTheFlagForGood() {
        let disputed = match.reporting(3, 1, by: "u1", at: noon).disputing()
        #expect(disputed.status == .pending && disputed.isDisputed && disputed.isOpenDispute)
        #expect(disputed.scoreA == nil && disputed.scoreB == nil && disputed.reportedBy == nil && disputed.reportedAt == nil)

        let timed = match.scheduling(MatchSchedule(scheduledAt: noon)).reporting(3, 1, by: "u1", at: noon).disputing()
        #expect(timed.status == .scheduled && timed.scheduledAt == noon, "a match with a time reopens as scheduled")

        let reportedAgain = disputed.reporting(2, 1, by: "u2", at: noon)
        #expect(reportedAgain.status == .reported && reportedAgain.isDisputed && !reportedAgain.isOpenDispute)
        let settled = disputed.recording(2, 1, by: "org", at: noon)
        #expect(settled.status == .confirmed && settled.isDisputed && !settled.isOpenDispute, "the flag is history, not state")
        #expect(!match.isOpenDispute)
    }

    @Test func aWalkoverDropsAnyReport() {
        let walkover = match.reporting(3, 1, by: "u1", at: noon).walkover(winnerEntryId: "e2", by: "org", at: noon)
        #expect(walkover.status == .walkover && walkover.winnerEntryId == "e2" && walkover.isDecided)
        #expect(walkover.scoreA == nil && walkover.scoreB == nil && walkover.reportedBy == nil && walkover.reportedAt == nil)
        #expect(walkover.confirmedBy == "org" && walkover.confirmedAt == noon)
    }

    /// A knockout match always needs a winner; a round robin follows `allowsDraws`.
    @Test func aKnockoutNeverPermitsDraws() {
        #expect(!Tournament.fixture(format: .singleElimination, allowsDraws: true).permitsDraws)
        #expect(Tournament.fixture(format: .roundRobin, allowsDraws: true).permitsDraws)
        #expect(!Tournament.fixture(format: .roundRobin, allowsDraws: false).permitsDraws)
    }
}
