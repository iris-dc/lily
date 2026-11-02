import Foundation
import Testing
@testable import lily

/// The protocol's defaults: a conformer declares its cases, `known` and `wireName`; the lookup by name, `isUnknown` and
/// the single-string coding come from the extension, so every kind reads the wire the same way.
struct WireNamedKindTests {
    private enum Colour: WireNamedKind {
        case red, green
        case unknown(String)

        static let known: [Colour] = [.red, .green]

        var wireName: String {
            switch self {
            case .red: "red"
            case .green: "green"
            case .unknown(let name): name
            }
        }
    }

    @Test func theDefaultsNameAKnownCaseAndKeepAnUnknownOne() throws {
        #expect(Colour(wireName: "green") == .green && !Colour.green.isUnknown)
        #expect(Colour(wireName: "teal") == .unknown("teal") && Colour(wireName: "teal").isUnknown)
        #expect(Colour.unknown("red") != .red, "a kept name never passes for the case it spells")

        let decoded = try JSONDecoder().decode([Colour].self, from: Data(#"["red","teal"]"#.utf8))
        #expect(decoded == [.red, .unknown("teal")])
        let encoded = try #require(String(bytes: try JSONEncoder().encode(decoded), encoding: .utf8))
        #expect(encoded == #"["red","teal"]"#, "an unseen name goes back out as it came")
    }
}
