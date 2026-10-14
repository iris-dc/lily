import Foundation
@testable import lily

/// The production inits take the user's currency and locale, which most tests do not care about: these fix them to the
/// fixtures' euro and to `en_US`, so a test that is not about money reads as before and price literals like "7.5" read
/// the same on every simulator.
extension EventDraft {
    static let testCurrencyCode = "EUR"
    static let testLocale = Locale(identifier: "en_US")

    init(startsAt: Date, clientId: String = UUID().uuidString.lowercased()) {
        self.init(startsAt: startsAt, currencyCode: Self.testCurrencyCode, locale: Self.testLocale, clientId: clientId)
    }

    init(editing event: SportEvent) {
        self.init(editing: event, currencyCode: Self.testCurrencyCode, locale: Self.testLocale)
    }
}
