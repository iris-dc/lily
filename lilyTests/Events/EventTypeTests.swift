import Testing
import UIKit
@testable import lily

struct EventTypeTests {
    @Test func multiWordTypesTravelInTheBackendsSnakeCase() {
        #expect(EventType.tableTennis.rawValue == "table_tennis")
        #expect(EventType.martialArts.rawValue == "martial_arts")
        #expect(EventType.boardGames.rawValue == "board_games")
        #expect(EventType(rawValue: "esports") == .esports && EventType(rawValue: "travel") == .travel)
    }

    @Test func everyTypeHasASymbolTheSystemKnows() {
        for type in EventType.allCases {
            #expect(UIImage(systemName: type.symbolName) != nil, "\(type.rawValue): \(type.symbolName)")
        }
    }

    @Test func everyTypeNamesItselfOnceAndOtherComesLast() {
        let names = EventType.allCases.map(\.displayName)
        #expect(Set(names).count == names.count)
        #expect(EventType.allCases.last == .other)
        #expect(EventType.esports.displayName == "Esports" && EventType.tableTennis.displayName == "Table tennis")
    }
}
