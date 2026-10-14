import Foundation
import Testing
import UIKit
@testable import lily

@MainActor
struct CurrencyStoreTests {
    @MainActor private final class Harness {
        let store = UserDefaultsChoiceStore<CurrencyPreference>(defaults: makeTestDefaults(), logger: SpyLogger())
        let logger = SpyLogger()
        var systemChoice: String? = "EUR"

        func makeStore() -> CurrencyStore {
            CurrencyStore(store: store, systemChoice: { [weak self] in self?.systemChoice }, logger: logger)
        }

        var infoLines: [String] { logger.messages(in: .currency, at: .info) }
    }

    @Test func startsFromTheStoredChoice() {
        let harness = Harness()
        harness.store.save(.fixed("PLN"))

        let store = harness.makeStore()

        #expect(store.preference == .fixed("PLN") && store.currencyCode == "PLN")
        let lines = harness.infoLines
        #expect(lines.count == 1)
        #expect(lines.last?.contains("PLN") == true && lines.last?.contains("chosen") == true)
    }

    @Test func withoutAChoiceItFollowsTheRegion() {
        let harness = Harness()
        harness.systemChoice = "USD"

        let store = harness.makeStore()

        #expect(store.preference == .system && store.currencyCode == "USD" && store.systemCurrencyCode == "USD")
        let lines = harness.infoLines
        #expect(lines.count == 1)
        #expect(lines.last?.contains("USD") == true && lines.last?.contains("system") == true)
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
        let afterChoice = harness.infoLines
        #expect(afterChoice.count == 2)
        #expect(afterChoice.last?.contains("GBP") == true && afterChoice.last?.contains("chosen") == true)

        store.select(.system)

        #expect(store.currencyCode == "EUR" && harness.store.load() == .system)
        let afterSystem = harness.infoLines
        #expect(afterSystem.count == 3)
        #expect(afterSystem.last?.contains("EUR") == true && afterSystem.last?.contains("system") == true)
    }

    @Test func selectingTheCurrentChoiceDoesNothing() {
        let harness = Harness()
        let store = harness.makeStore()

        store.select(.system)

        #expect(harness.infoLines.count == 1)
    }

    @Test func theRegionIsReadOnEveryAsk() {
        let harness = Harness()
        let store = harness.makeStore()

        harness.systemChoice = "CHF"

        #expect(store.currencyCode == "CHF", "a region change needs no relaunch")
    }

    @Test func theRowsSymbolsExist() {
        #expect(UIImage(systemName: DesignTokens.Symbols.currency) != nil)
        #expect(UIImage(systemName: DesignTokens.Symbols.menuChevron) != nil)
    }
}
