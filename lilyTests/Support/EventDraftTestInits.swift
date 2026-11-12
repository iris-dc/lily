import Foundation
@testable import lily

/// The production inits take the user's currency and locale, which most tests do not care about: these fix them to the
/// fixtures' euro and to `en_US`, so price literals like "7.5" parse the same on every simulator.
extension EventDraft {
    static let testCurrencyCode = "EUR"
    static let testLocale = Locale(identifier: "en_US")

    init(startsAt: Date, clientId: String = UUID().uuidString.lowercased()) {
        self.init(startsAt: startsAt, currencyCode: Self.testCurrencyCode, locale: Self.testLocale, clientId: clientId)
    }

    init(editing event: SportEvent) {
        self.init(editing: event, currencyCode: Self.testCurrencyCode, locale: Self.testLocale)
    }

    /// Fills in what a valid draft needs beyond the defaults; `nil` exercises the missing-coordinate paths. The spot
    /// counts as picked on the map whatever the coordinate, so the round-5 choice rule is satisfied like a user's
    /// own pick and the resolver leaves the spot alone like a user's own choice.
    mutating func fillRequired(coordinate: Coordinate? = AppConfig.Location.mockCenter) {
        title = "Thursday five-a-side"
        locationName = "Test Park"
        self.coordinate = coordinate
        spotPickedOnMap = true
    }
}
