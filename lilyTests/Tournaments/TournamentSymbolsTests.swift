import Testing
import UIKit
@testable import lily

/// Every SF Symbol the tournament screens name exists, so a misspelt name fails here instead of drawing nothing.
struct TournamentSymbolsTests {
    private typealias Symbols = DesignTokens.Symbols

    @Test func everyTournamentSymbolExists() {
        let names = [Symbols.tournament, Symbols.bracket, Symbols.standings, Symbols.team, Symbols.captain, Symbols.format,
                     Symbols.registrationCloses, Symbols.disputed, Symbols.walkover, Symbols.scheduled, Symbols.play,
                     Symbols.winner]
        for name in names {
            #expect(UIImage(systemName: name) != nil, "no SF Symbol named \(name)")
        }
    }
}
