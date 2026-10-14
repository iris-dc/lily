import Foundation
import Testing
@testable import lily

struct MeasurementRoadTests {
    private let german = Locale(identifier: "de_DE")
    private let american = Locale(identifier: "en_US")

    @Test func roadTextFollowsTheGivenLocale() {
        let distance = Measurement(value: 1_623, unit: UnitLength.meters)

        #expect(plainSpaced(distance.roadText(locale: german)) == "1,6 km", "one decimal, the locale's separator")

        let miles = distance.roadText(locale: american)
        #expect(miles.contains("mi") && !miles.contains("km"), "the locale's units")
    }

    @Test func aShortRoadDistanceStaysInMeters() {
        let distance = Measurement(value: 800, unit: UnitLength.meters)
        #expect(plainSpaced(distance.roadText(locale: german)) == "800 m")
    }

    /// Foundation puts a narrow or regular no-break space between number and unit on some systems.
    private func plainSpaced(_ text: String) -> String {
        text.replacingOccurrences(of: "\u{202F}", with: " ").replacingOccurrences(of: "\u{00A0}", with: " ")
    }
}
