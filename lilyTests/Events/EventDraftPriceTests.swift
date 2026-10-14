import Foundation
import Testing
@testable import lily

/// The price on a draft: the field's text is the source, the amount is read from it in the draft's locale, and both are
/// judged at the backend's limits. An extension because the main suite's body is at the SwiftLint limit.
extension EventDraftTests {
    /// The backend takes at most seven integer digits and two decimals; zero and nothing both mean free. A minus is
    /// not a refused amount but unreadable text: the decimal pad has none.
    static let acceptedPrices: [String?] = [nil, "0", "5", "7.5", "12.99", "9999999.99"]
    static let refusedPrices = ["0.001", "10000000"]
    /// Text the parser cannot read in the draft's locale (en_US here): a minus, a symbol, a code, a foreign or a
    /// stray separator, letters.
    private static let unreadablePrices = ["-1", "€5", "$5", "5 EUR", "5,50", "5..5", "5.5.5", "abc"]

    /// One place turns a draft's amount into a `Price`: free (nothing or zero) is no price at all.
    @Test func thePriceIsAbsentForAFreeGameAndCarriesTheCurrencyOtherwise() {
        var draft = Self.makeValidDraft()
        #expect(draft.eventPrice == nil)

        draft.price = 0
        #expect(draft.eventPrice == nil)

        draft.price = 5
        #expect(draft.eventPrice == Price(amount: 5, currencyCode: EventDraft.testCurrencyCode))

        var dollars = EventDraft(startsAt: Self.now, currencyCode: "USD")
        dollars.price = 5
        #expect(dollars.eventPrice == Price(amount: 5, currencyCode: "USD"), "the price is in the draft's currency")
    }

    @Test(arguments: acceptedPrices)
    func pricesWithinTheLimitsPass(text: String?) {
        var draft = Self.makeValidDraft()

        draft.priceText = text ?? ""

        #expect(issues(of: draft).isEmpty)
    }

    @Test(arguments: refusedPrices)
    func pricesBeyondTheLimitsAreRefused(text: String) {
        var draft = Self.makeValidDraft()

        draft.priceText = text

        #expect(issues(of: draft) == [.priceOutOfRange])
    }

    /// Unreadable text holds the submit instead of making the game free or misreading the amount ("5,50" once
    /// read as 550 in en_US).
    @Test(arguments: unreadablePrices)
    func aPriceTheParserCannotReadHoldsTheSubmit(text: String) {
        var draft = Self.makeValidDraft()

        draft.priceText = text

        #expect(draft.price == nil)
        #expect(draft.hasUnreadablePrice)
        #expect(issues(of: draft) == [.priceUnreadable])
        #expect(!draft.isValid(now: Self.now))
    }

    /// Blank is empty, not unreadable: the game is free and nothing holds it.
    @Test func aBlankPriceIsFreeAndRaisesNoIssue() {
        var draft = Self.makeValidDraft()

        draft.priceText = "   "

        #expect(!draft.hasUnreadablePrice)
        #expect(draft.isFree)
        #expect(issues(of: draft).isEmpty)
    }

    @Test func zeroOrNoPriceMeansFree() {
        var draft = Self.makeValidDraft()
        #expect(draft.isFree)

        draft.price = 0
        #expect(draft.isFree)

        draft.price = 5
        #expect(!draft.isFree)
    }

    /// The field's text is what the draft holds; the amount is read from it, and setting an amount types it as the
    /// field would show it.
    @Test func thePriceTextIsTheSourceAndTheAmountReadsIt() {
        var draft = Self.makeValidDraft()

        draft.priceText = "7.5"
        #expect(draft.price == Decimal(string: "7.5"))

        draft.priceText = "  5  "
        #expect(draft.price == 5)

        draft.price = Decimal(string: "12.5")
        #expect(draft.priceText == "12.5")

        draft.price = nil
        #expect(draft.priceText.isEmpty && draft.isFree)
    }

    /// An edit seeds the text in the draft's locale and reads it back in the same one, so the two cannot disagree.
    @Test func anEditSeedsThePriceTextInTheDraftsLocaleAndReadsItBack() throws {
        let amount = try #require(Decimal(string: "7.5"))
        let event = SportEvent.fixture(price: Price(amount: amount, currencyCode: "EUR"))

        let american = EventDraft(editing: event)
        #expect(american.priceText == "7.5" && american.price == amount)

        let german = EventDraft(editing: event, currencyCode: "EUR", locale: Locale(identifier: "de_DE"))
        #expect(german.priceText == "7,5" && german.price == amount)

        #expect(EventDraft(editing: .fixture()).priceText.isEmpty)
    }
}
