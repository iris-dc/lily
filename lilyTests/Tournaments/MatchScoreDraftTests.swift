import Foundation
import Testing
@testable import lily

/// The match sheet's score fields, as `MatchScoreDraft` holds them: what they open with, what parses, and what keeps
/// Report or Record disabled.
struct MatchScoreDraftTests {
    private let noon = Date(timeIntervalSince1970: 1_800_014_400)
    private let match = TournamentMatch(id: "r01p001",
                                        tournamentId: "t",
                                        round: 1,
                                        position: 1,
                                        entryAId: "e1",
                                        entryBId: "e2")

    private func draft(_ scoreA: String, _ scoreB: String) -> MatchScoreDraft {
        var draft = MatchScoreDraft(match: nil)
        draft.scoreA = scoreA
        draft.scoreB = scoreB
        return draft
    }

    @Test func bothScoresParseWithinTheRange() {
        let scores = draft("3", "1").parsed
        #expect(scores?.a == 3 && scores?.b == 1)
        #expect(draft("3", "1").canSubmit(permitsDraws: false))

        let bounds = draft("0", "999").parsed
        #expect(bounds?.a == 0 && bounds?.b == 999, "the bounds of the range are in")
        #expect(draft("0", "999").canSubmit(permitsDraws: false))
    }

    @Test(arguments: ["", "x", "1000", "-1"])
    func aBlankANonDigitAThousandOrANegativeHoldsTheSend(scoreA: String) {
        let scores = draft(scoreA, "1")
        #expect(scores.parsed == nil)
        #expect(!scores.canSubmit(permitsDraws: true))
        #expect(!scores.isDisallowedDraw(permitsDraws: false), "an unparsed pair is no draw")
    }

    @Test func aTiedScoreHoldsTheSendOnAKnockoutAndPassesOnARoundRobinWithDraws() {
        let tied = draft("2", "2")
        #expect(tied.isDisallowedDraw(permitsDraws: false))
        #expect(!tied.canSubmit(permitsDraws: false))
        #expect(!tied.isDisallowedDraw(permitsDraws: true))
        #expect(tied.canSubmit(permitsDraws: true))
    }

    @Test func theDraftOpensOnTheReportedScoreAndEmptyOtherwise() {
        let reported = MatchScoreDraft(match: match.reporting(3, 2, by: "u", at: noon))
        #expect(reported.scoreA == "3" && reported.scoreB == "2")

        let pending = MatchScoreDraft(match: match)
        #expect(pending.scoreA.isEmpty && pending.scoreB.isEmpty)

        let none = MatchScoreDraft(match: nil)
        #expect(none.scoreA.isEmpty && none.scoreB.isEmpty)
    }
}
