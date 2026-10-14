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

    /// The Profile menu names each currency in the user's locale.
    @Test func currenciesAreNamedInTheUsersLocale() {
        #expect(Price.name(for: "PLN", locale: us) == "Polish Zloty")
        #expect(Price.name(for: euro, locale: Locale(identifier: "pl_PL")) == "euro")
        #expect(Price.symbol(for: "PLN", locale: Locale(identifier: "pl_PL")) == "zł")
    }

    /// A code the locale cannot name shows as itself. ISO's own "no currency" code XXX is named, so only ZZZ exercises
    /// the fallback.
    @Test func anUnassignedCurrencyCodeNamesItself() {
        #expect(Price.name(for: "ZZZ", locale: us) == "ZZZ")
        #expect(Price.name(for: "XXX", locale: us) == "Unknown Currency")
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

    /// Typed amounts (the filter's cap, a new game's price) are read in the user's locale, whole and trimmed; empty,
    /// unreadable (a symbol, a code, a stray separator) or negative text is no amount at all.
    @Test func typedAmountsAreParsedInTheLocale() {
        #expect(Price.parseAmount("6.5", locale: us) == Decimal(string: "6.5"))
        #expect(Price.parseAmount("6,5", locale: germany) == Decimal(string: "6.5"))
        #expect(Price.parseAmount("6", locale: germany) == 6)
        #expect(Price.parseAmount("0", locale: us) == 0)
        #expect(Price.parseAmount("5.", locale: us) == 5)
        #expect(Price.parseAmount(".5", locale: us) == Decimal(string: "0.5"))
        #expect(Price.parseAmount(" 7.5 ", locale: us) == Decimal(string: "7.5"))
        for text in ["", "abc", "-3", "€5", "$5", "5 EUR", "5..5", "5.5.5", "1,500"] {
            #expect(Price.parseAmount(text, locale: us) == nil, "\(text)")
        }
    }

    /// A separator of another locale is refused, never read as a grouping one: a lenient parse makes en_US "5,50" into
    /// 550, and "7.50" into 750 for a French app on an en_CA device.
    @Test func aForeignSeparatorIsNeverAHundredfold() {
        let frenchCanada = Locale(identifier: "fr_CA")
        #expect(Price.parseAmount("5,50", locale: us) == nil)
        #expect(Price.parseAmount("5.50", locale: germany) == nil)
        #expect(Price.parseAmount("7.50", locale: frenchCanada) == nil)
        #expect(Price.parseAmount("7,50", locale: frenchCanada) == Decimal(string: "7.5"))
        #expect(Price.parseAmount("5,5", locale: germany) == Decimal(string: "5.5"))
    }

    /// The forms seed their price fields with `inputText` and parse what they hold with `parseAmount`, so the two
    /// must agree in every locale, without a grouping separator (which the strict parse would refuse), or opening a
    /// game would change its price.
    @Test func aFormattedAmountReadsBackUnchanged() {
        #expect(Price.inputText(1500, locale: us) == "1500")
        let amounts = ["7.5", "12", "0.99", "1500", "1234.5", "9999999.99"].map { Decimal(string: $0)! }
        for locale in [us, germany, Locale(identifier: "fr_CA"), Locale(identifier: "pl_PL")] {
            for amount in amounts {
                let text = Price.inputText(amount, locale: locale)
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
