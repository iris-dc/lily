import Foundation
import Testing
@testable import lily

/// Who may do what with a match, for every status and every kind of caller.
struct MatchActionsTests {
    private let me = TestFixtures.user.id
    private let entries = [TournamentEntry.fixture(id: "e1", name: "Me", captainUserId: TestFixtures.user.id, seed: 1),
                           TournamentEntry.fixture(id: "e2", name: "Jonas", captainUserId: "u-2", seed: 2),
                           TournamentEntry.fixture(id: "e3", name: "Dev", captainUserId: "u-3", seed: 3)]

    private func detail(status: TournamentStatus = .inProgress,
                        organizer: String = "org",
                        myEntryId: String? = "e1") -> TournamentDetail {
        .fixture(tournament: .fixture(status: status, organizerUserId: organizer, myEntryId: myEntryId), entries: entries)
    }

    private func match(_ status: MatchStatus = .pending, reportedBy: String? = nil, entryB: String? = "e2") -> TournamentMatch {
        TournamentMatch(id: "r01p001",
                        tournamentId: "t",
                        round: 1,
                        position: 1,
                        entryAId: "e1",
                        entryBId: entryB,
                        status: status,
                        scoreA: status == .pending ? nil : 3,
                        scoreB: status == .pending ? nil : 1,
                        reportedBy: reportedBy)
    }

    @Test func nothingIsOfferedBeforeTheStartToGuestsOutsidersOrInSomeoneElsesMatch() {
        #expect(MatchActions(detail: detail(status: .registration), match: match(), userID: me) == .none)
        #expect(MatchActions(detail: detail(status: .completed), match: match(), userID: me) == .none)
        #expect(MatchActions(detail: detail(), match: match(), userID: nil) == .none)
        #expect(MatchActions(detail: detail(myEntryId: nil), match: match(), userID: me) == .none, "an outsider")
        let others = TournamentMatch(id: "r01p002", tournamentId: "t", round: 1, position: 2, entryAId: "e2", entryBId: "e3")
        #expect(MatchActions(detail: detail(), match: others, userID: me) == .none, "not the caller's match")
        #expect(MatchActions(detail: detail(), match: match(entryB: nil), userID: me).isEmpty, "a side still to be decided")
    }

    @Test func aSideReportsUntilTheOtherSideHasReportedThenConfirmsOrDisputes() {
        let pending = MatchActions(detail: detail(), match: match(), userID: me)
        #expect(pending.canReport && pending.takesScore && !pending.canConfirm && !pending.canDispute)
        #expect(!pending.canRecord && !pending.canWalkover && !pending.awaitsOtherSide)
        #expect(MatchActions(detail: detail(), match: match(.scheduled), userID: me).canReport)

        let theirs = MatchActions(detail: detail(), match: match(.reported, reportedBy: "u-2"), userID: me)
        #expect(theirs.canConfirm && theirs.canDispute && !theirs.canReport && !theirs.awaitsOtherSide)

        let mine = MatchActions(detail: detail(), match: match(.reported, reportedBy: me), userID: me)
        #expect(mine.awaitsOtherSide && mine.canReport && !mine.canConfirm && !mine.canDispute, "a correction is still possible")

        for decided in [MatchStatus.confirmed, .walkover, .bye] {
            #expect(MatchActions(detail: detail(), match: match(decided), userID: me) == .none, "\(decided) is final for a side")
        }
    }

    /// A teammate's report is the team's own.
    @Test func aTeammatesReportCountsAsTheCallersSide() {
        let members = [EntryMember(userId: "u-9", displayName: "Cap"), EntryMember(userId: me, displayName: "Me")]
        let team = TournamentEntry.fixture(id: "e1", name: "Us", captainUserId: "u-9", members: members)
        let detail = TournamentDetail.fixture(tournament: .fixture(status: .inProgress, teamSize: 2, myEntryId: "e1"),
                                              entries: [team, entries[1]])
        let actions = MatchActions(detail: detail, match: match(.reported, reportedBy: "u-9"), userID: me)
        #expect(actions.awaitsOtherSide && !actions.canConfirm)
    }

    @Test func theOrganiserRecordsGivesWalkoversAndConfirmsReports() {
        let pending = MatchActions(detail: detail(organizer: me, myEntryId: nil), match: match(), userID: me)
        #expect(pending.canRecord && pending.canWalkover && pending.takesScore && !pending.canReport && !pending.canConfirm)

        let theirReport = match(.reported, reportedBy: "u-2")
        let reported = MatchActions(detail: detail(organizer: me, myEntryId: nil), match: theirReport, userID: me)
        #expect(reported.canRecord && reported.canConfirm && reported.canWalkover && !reported.canDispute)

        #expect(MatchActions(detail: detail(organizer: me, myEntryId: nil), match: match(.confirmed), userID: me) == .none)
        let unpaired = MatchActions(detail: detail(organizer: me, myEntryId: nil), match: match(entryB: nil), userID: me)
        #expect(unpaired.canSchedule && !unpaired.canRecord && !unpaired.canWalkover, "a time may be set before the sides are")
        let playing = MatchActions(detail: detail(organizer: me), match: match(), userID: me)
        #expect(playing.canRecord && !playing.canReport, "an organiser who plays still records")
    }

    /// The time and place are the organiser's to set on any match not yet decided; a side never schedules.
    @Test func onlyTheOrganiserSchedulesAndOnlyAnUndecidedMatch() {
        for open in [MatchStatus.pending, .scheduled, .reported] {
            #expect(MatchActions(detail: detail(organizer: me, myEntryId: nil), match: match(open), userID: me).canSchedule)
            #expect(!MatchActions(detail: detail(), match: match(open), userID: me).canSchedule, "a side: \(open)")
        }
        for decided in [MatchStatus.confirmed, .walkover, .bye] {
            #expect(!MatchActions(detail: detail(organizer: me, myEntryId: nil), match: match(decided), userID: me).canSchedule)
        }
        #expect(!MatchActions(detail: detail(status: .registration, organizer: me, myEntryId: nil), match: match(), userID: me)
            .canSchedule)
    }
}
