import Foundation
import Testing
@testable import lily

/// What the detail offers whom, decided from the tournament and the caller's id.
struct TournamentParticipationTests {
    private static let now = Date(timeIntervalSince1970: 1_800_000_000)
    private static let ahead = now.addingTimeInterval(86_400)

    struct Case: CustomTestStringConvertible {
        let name: String
        let tournament: Tournament
        let userID: String?
        let expected: TournamentParticipation

        var testDescription: String { name }
    }

    private static let cases: [Case] = [
        Case(name: "guest", tournament: .fixture(startsAt: ahead), userID: nil, expected: .hidden),
        Case(name: "individual, open, not in", tournament: .fixture(startsAt: ahead), userID: "u", expected: .join),
        Case(name: "team, open, not in", tournament: .fixture(teamSize: 5, startsAt: ahead), userID: "u", expected: .createTeam),
        Case(name: "entered, open", tournament: .fixture(startsAt: ahead, myEntryId: "e"), userID: "u", expected: .leave),
        Case(name: "entered, started",
             tournament: .fixture(status: .inProgress, myEntryId: "e"),
             userID: "u",
             expected: .entered),
        Case(name: "entered, past the deadline",
             tournament: .fixture(startsAt: ahead, registrationClosesAt: now.addingTimeInterval(-1), myEntryId: "e"),
             userID: "u",
             expected: .entered),
        Case(name: "not in, started", tournament: .fixture(status: .inProgress), userID: "u", expected: .registrationClosed),
        Case(name: "not in, cancelled",
             tournament: .fixture(status: .cancelled, startsAt: ahead),
             userID: "u",
             expected: .registrationClosed),
        Case(name: "not in, past the deadline",
             tournament: .fixture(startsAt: ahead, registrationClosesAt: now.addingTimeInterval(-1)),
             userID: "u",
             expected: .registrationClosed),
        Case(name: "full, not in",
             tournament: .fixture(maxEntries: 4, entryCount: 4, startsAt: ahead),
             userID: "u",
             expected: .full),
        Case(name: "full, entered",
             tournament: .fixture(maxEntries: 4, entryCount: 4, startsAt: ahead, myEntryId: "e"),
             userID: "u",
             expected: .leave),
        Case(name: "organiser, not in, open",
             tournament: .fixture(startsAt: ahead, organizerUserId: "u"),
             userID: "u",
             expected: .join),
    ]

    @Test(arguments: cases)
    func participationFollowsTheMatrix(_ testCase: Case) {
        let participation = TournamentParticipation(tournament: testCase.tournament, userID: testCase.userID, now: Self.now)
        #expect(participation == testCase.expected)
    }

    @Test func rolesPutTheOrganiserFirst() {
        let tournament = Tournament.fixture(organizerUserId: "org", myEntryId: "e1")
        #expect(TournamentRole(tournament: tournament, userID: nil) == .guest)
        #expect(TournamentRole(tournament: tournament, userID: "org") == .organizer)
        #expect(TournamentRole(tournament: tournament, userID: "player") == .entrant(entryID: "e1"))
        #expect(TournamentRole(tournament: .fixture(), userID: "someone") == .outsider)
        #expect(TournamentRole.organizer.isOrganizer && TournamentRole.guest.isGuest && !TournamentRole.outsider.isOrganizer)
    }

    @Test func joiningATeamIsOfferedWhileTheCallerMayStillEnter() {
        #expect(TournamentParticipation.createTeam.offersJoiningATeam)
        for other in [TournamentParticipation.hidden, .join, .leave, .entered, .registrationClosed, .full] {
            #expect(!other.offersJoiningATeam)
        }
    }
}
