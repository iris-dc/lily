import Foundation
import Testing
@testable import lily

/// The optional details a host may add: price, level, description and who they are looking for.
struct EventDetailsTests {
    private let euro = "EUR"
    private let us = Locale(identifier: "en_US")
    private let germany = Locale(identifier: "de_DE")

    /// Currency formatting uses non-breaking spaces; compare on plain ones so the expectation reads naturally.
    private func plain(_ text: String) -> String {
        String(text.map { $0.isWhitespace ? " " : $0 })
    }

    @Test func missingPriceMeansFree() {
        let event = SportEvent.fixture()
        #expect(event.isFree)
        #expect(event.priceText == "Free")
        #expect(event.skillLevel == nil && event.description == nil && event.lookingFor == nil)
    }

    @Test func zeroPriceIsFreeToo() {
        let event = SportEvent.fixture(price: Price(amount: 0, currencyCode: euro))
        #expect(event.isFree)
        #expect(event.priceText == "Free")
    }

    @Test func wholeAmountsDropTheMinorUnits() {
        let price = Price(amount: 5, currencyCode: euro)
        #expect(!price.isFree)
        #expect(price.text(in: us) == "€5")
        #expect(plain(price.text(in: germany)) == "5 €")
        #expect(Price(amount: Decimal(string: "12.00")!, currencyCode: euro).text(in: us) == "€12")
    }

    @Test func fractionalAmountsKeepTheCurrencyUsualDecimals() {
        let price = Price(amount: 7.5, currencyCode: euro)
        #expect(price.text(in: us) == "€7.50")
        #expect(plain(price.text(in: germany)) == "7,50 €")
        #expect(SportEvent.fixture(price: price).priceText == price.text)
    }

    @Test func currencySymbolFollowsTheLocale() {
        #expect(Price.symbol(for: "EUR", locale: us) == "€")
        #expect(Price.symbol(for: "EUR", locale: germany) == "€")
        #expect(Price.symbol(for: "USD", locale: us) == "$")
    }

    /// Typed amounts (the filter's cap, a new game's price) are read in the user's locale; empty, unreadable or
    /// negative text is no amount at all.
    @Test func typedAmountsAreParsedInTheLocale() {
        #expect(Price.parseAmount("6.5", locale: us) == Decimal(string: "6.5"))
        #expect(Price.parseAmount("6,5", locale: germany) == Decimal(string: "6.5"))
        #expect(Price.parseAmount("6", locale: germany) == 6)
        #expect(Price.parseAmount("0", locale: us) == 0)
        for text in ["", "abc", "-3"] {
            #expect(Price.parseAmount(text, locale: us) == nil, "\(text)")
        }
    }

    /// The edit form seeds its price field with `inputFormat` and parses what it holds with `parseAmount`, so the
    /// two must agree in every locale, grouping separators included, or opening a game would change its price.
    @Test func aFormattedAmountReadsBackUnchanged() {
        let amounts = ["7.5", "12", "0.99", "1234.5", "9999999.99"].map { Decimal(string: $0)! }
        for locale in [us, germany] {
            for amount in amounts {
                let text = amount.formatted(Price.inputFormat.locale(locale))
                #expect(Price.parseAmount(text, locale: locale) == amount, "\(text) in \(locale.identifier)")
            }
        }
    }

    @Test func levelCopyNamesTheLevel() {
        #expect(AppBranding.Events.level(SkillLevel.intermediate.displayName) == "Intermediate level")
        #expect(AppBranding.Events.perPerson("€5") == "€5 per person")
    }

    /// Payloads written before these fields existed must keep decoding, with every detail absent.
    @Test func decodesPayloadsWithoutTheOptionalDetails() throws {
        let full = SportEvent.fixture(skillLevel: .advanced, price: Price(amount: 5, currencyCode: euro))
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(full)) as? [String: Any]
        for key in ["description", "lookingFor", "skillLevel", "price"] { json?.removeValue(forKey: key) }
        let data = try JSONSerialization.data(withJSONObject: json ?? [:])

        let decoded = try JSONDecoder().decode(SportEvent.self, from: data)

        #expect(decoded.id == full.id)
        #expect(decoded.price == nil && decoded.skillLevel == nil)
        #expect(decoded.isFree)
    }

    @Test func detailsSurviveACodableRoundTrip() throws {
        let event = SportEvent.fixture(startsAt: Date(timeIntervalSince1970: 1_700_000_000),
                                       description: "d",
                                       lookingFor: "one more",
                                       skillLevel: .beginner,
                                       price: Price(amount: 7.5, currencyCode: euro))
        let decoded = try JSONDecoder().decode(SportEvent.self, from: JSONEncoder().encode(event))
        #expect(decoded == event)
    }

    /// The feed should show every detail present and absent at least once, so each surface is seen both ways.
    @Test func feedSizedFixturesCoverDetailsPresentAndAbsent() {
        let events = MockEventFixtures.make(now: .now, count: AppConfig.Events.mockFeedSize)
        #expect(events.contains { $0.description != nil } && events.contains { $0.description == nil })
        #expect(events.contains { $0.lookingFor != nil } && events.contains { $0.lookingFor == nil })
        #expect(events.contains { $0.skillLevel != nil } && events.contains { $0.skillLevel == nil })
        #expect(events.contains { !$0.isFree } && events.contains(where: \.isFree))
        #expect(events.allSatisfy { ($0.price?.amount ?? 0) >= 0 })
    }
}
