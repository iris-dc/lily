import Foundation
import Testing
@testable import lily

struct TournamentConfirmationTests {
    @Test func eachConfirmationHasItsWords() {
        let entry = TournamentEntry.fixture(id: "e", name: "Görli Giants")
        #expect(TournamentConfirmation.start.title(name: "Kickers Cup") == "Start Kickers Cup?")
        #expect(TournamentConfirmation.start.message(entries: "5 of 8 teams")
            == "5 of 8 teams are in. Registration closes and the matches are drawn.")
        #expect(TournamentConfirmation.start.buttonTitle == "Start tournament" && !TournamentConfirmation.start.isDestructive)
        #expect(TournamentConfirmation.cancel.title(name: "Kickers Cup").hasPrefix("Cancel Kickers Cup?"))
        #expect(TournamentConfirmation.cancel.message(entries: "x") == nil)
        #expect(TournamentConfirmation.cancel.isDestructive)
        #expect(TournamentConfirmation.leave.buttonTitle == "Leave tournament" && TournamentConfirmation.leave.isDestructive)
        let removal = TournamentConfirmation.removeEntry(entry)
        #expect(removal.title(name: "Kickers Cup") == "Remove Görli Giants from the tournament?")
        #expect(TournamentConfirmation.removeEntry(entry).buttonTitle == "Remove entry")
    }
}
