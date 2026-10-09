import Foundation
import Testing
import UIKit
@testable import lily

@MainActor
struct CurrencyStoreTests {
    @MainActor private final class Harness {
        let store = UserDefaultsCurrencyPreferenceStore(defaults: makeTestDefaults())
        let logger = SpyLogger()
        var systemChoice: String? = "EUR"

        func makeStore() -> CurrencyStore {
            CurrencyStore(store: store, systemChoice: { [weak self] in self?.systemChoice }, logger: logger)
        }
    }

    @Test func startsFromTheStoredChoice() {
        let harness = Harness()
        harness.store.save(.fixed("PLN"))

        let store = harness.makeStore()

        #expect(store.preference == .fixed("PLN") && store.currencyCode == "PLN")
        #expect(harness.logger.messages(in: .currency) == ["Currency PLN (chosen)"])
    }

    @Test func withoutAChoiceItFollowsTheRegion() {
        let harness = Harness()
        harness.systemChoice = "USD"

        let store = harness.makeStore()

        #expect(store.preference == .system && store.currencyCode == "USD" && store.systemCurrencyCode == "USD")
        #expect(harness.logger.messages(in: .currency) == ["Currency USD (system)"])
    }

    @Test func aRegionWithoutACurrencyFallsBackToTheDefault() {
        let harness = Harness()
        harness.systemChoice = nil

        let store = harness.makeStore()

        #expect(store.currencyCode == AppConfig.Currency.defaultCode)
        #expect(store.systemCurrencyCode == AppConfig.Currency.defaultCode)
    }

    @Test func selectingSavesAndPublishesTheCurrency() {
        let harness = Harness()
        let store = harness.makeStore()

        store.select(.fixed("GBP"))

        #expect(store.currencyCode == "GBP" && harness.store.load() == .fixed("GBP"))
        #expect(harness.logger.messages(in: .currency).last == "Currency changed to GBP (chosen)")

        store.select(.system)

        #expect(store.currencyCode == "EUR" && harness.store.load() == .system)
        #expect(harness.logger.messages(in: .currency).last == "Currency changed to EUR (system)")
    }

    @Test func selectingTheCurrentChoiceDoesNothing() {
        let harness = Harness()
        let store = harness.makeStore()

        store.select(.system)

        #expect(harness.logger.messages(in: .currency).count == 1)
    }

    @Test func theRegionIsReadOnEveryAsk() {
        let harness = Harness()
        let store = harness.makeStore()

        harness.systemChoice = "CHF"

        #expect(store.currencyCode == "CHF", "a region change needs no relaunch")
    }

    @Test func theDefaultSystemChoiceIsTheLocalesCurrency() {
        let store = CurrencyStore(store: UserDefaultsCurrencyPreferenceStore(defaults: makeTestDefaults()),
                                  logger: SpyLogger())

        #expect(store.systemCurrencyCode == (AppLocale.locale.currency?.identifier ?? AppConfig.Currency.defaultCode))
    }

    @Test func theRowsSymbolsExist() {
        #expect(UIImage(systemName: DesignTokens.Symbols.currency) != nil)
        #expect(UIImage(systemName: DesignTokens.Symbols.menuChevron) != nil)
    }
}
