import Foundation
@testable import lily

/// The production inits take the user's currency, which most tests do not care about: these fix it to the fixtures'
/// euro, so a test that is not about money reads as before.
extension EventDraft {
    static let testCurrencyCode = "EUR"

    init(startsAt: Date, clientId: String = UUID().uuidString.lowercased()) {
        self.init(startsAt: startsAt, currencyCode: Self.testCurrencyCode, clientId: clientId)
    }

    init(editing event: SportEvent) {
        self.init(editing: event, currencyCode: Self.testCurrencyCode)
    }
}
