import Foundation
import Testing
@testable import lily

/// The detail model's derived rules: what `TournamentDetail` answers from its tournament, entries and matches. The
/// `TournamentDetail*Tests` suites next to this one are the view model's.
struct TournamentDetailModelTests {
    @Test func registeredEntriesComeInSeedOrder() {
        let entries: [TournamentEntry] = [
            .fixture(id: "e3", seed: 3),
            .fixture(id: "e1", seed: 1),
            .fixture(id: "e2", seed: 2),
            .fixture(id: "e0", seed: 0, status: .withdrawn)
        ]
        let detail = TournamentDetail.fixture(entries: entries)

        #expect(detail.registeredEntries.map(\.id) == ["e1", "e2", "e3"],
                "the withdrawn entry is out and the rest come by seed, not by arrival")
        #expect(detail.entries.map(\.id) == ["e3", "e1", "e2", "e0"], "the stored list keeps the given order")
    }

    @Test func drawsBracketFollowsTheFormat() {
        #expect(TournamentFormat.singleElimination.drawsBracket)
        #expect(!TournamentFormat.roundRobin.drawsBracket)

        let knockout = Tournament.fixture(format: .singleElimination)
        let league = Tournament.fixture(format: .roundRobin)
        #expect(TournamentDetailSection.results.title(for: knockout) == AppBranding.Tournaments.bracketSection,
                "the title reads by format before the start, not once a match exists")
        #expect(TournamentDetailSection.results.title(for: league) == AppBranding.Tournaments.standingsSection)
        for section in [TournamentDetailSection.entries, .matches] {
            #expect(section.title(for: knockout) == section.title(for: league), "only the results title follows the format")
        }
    }
}
