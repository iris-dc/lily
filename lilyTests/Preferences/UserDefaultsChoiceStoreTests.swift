import Foundation
import Testing
@testable import lily

/// The one `UserDefaults` store behind both Profile choices. A value this build cannot read is a warning naming the
/// key on every load and reads as the system choice, which is why `LanguageStore` and `CurrencyStore` load once.
@MainActor
struct UserDefaultsChoiceStoreTests {
    private let defaults = makeTestDefaults()
    private let logger = SpyLogger()

    private var languages: UserDefaultsChoiceStore<LanguagePreference> {
        UserDefaultsChoiceStore(defaults: defaults, logger: logger)
    }

    private var currencies: UserDefaultsChoiceStore<CurrencyPreference> {
        UserDefaultsChoiceStore(defaults: defaults, logger: logger)
    }

    @Test func aStoredChoiceRoundTrips() {
        languages.save(.fixed(.polish))
        #expect(languages.load() == .fixed(.polish))

        currencies.save(.fixed("PLN"))
        #expect(currencies.load() == .fixed("PLN"))

        languages.save(.system)
        #expect(languages.load() == .system)
    }

    @Test func nothingStoredReadsAsSystemWithoutALogLine() {
        #expect(languages.load() == .system)
        #expect(currencies.load() == .system)
        #expect(logger.messages(in: .localization).isEmpty && logger.messages(in: .currency).isEmpty)
    }

    @Test func anUnreadableStoredChoiceIsLoggedOnceAndReadsAsSystem() {
        defaults.set("klingon", forKey: LanguagePreference.storageKey)

        #expect(languages.load() == .system)
        let warnings = logger.messages(in: .localization, at: .warning)
        #expect(warnings.count == 1)
        #expect(warnings.first?.contains(LanguagePreference.storageKey) == true, "the key is named")
        #expect(warnings.first?.contains("klingon") == false, "the value never is")

        _ = languages.load()

        #expect(logger.messages(in: .localization, at: .warning).count == 2, "every load warns again; the stores load once")
    }

    @Test func anUnreadableStoredCurrencyIsLoggedOnceAndReadsAsSystem() {
        defaults.set("pln", forKey: CurrencyPreference.storageKey)

        #expect(currencies.load() == .system)
        #expect(logger.messages(in: .currency, at: .warning).count == 1)
        #expect(logger.messages(in: .localization).isEmpty)
    }

    @Test func aStoredSystemChoiceWarnsNothing() {
        defaults.set(AppConfig.Storage.systemChoiceValue, forKey: LanguagePreference.storageKey)
        defaults.set(AppConfig.Storage.systemChoiceValue, forKey: CurrencyPreference.storageKey)

        #expect(languages.load() == .system && currencies.load() == .system)
        #expect(logger.entries.isEmpty)
    }

    @Test func clearForgetsTheChoice() {
        languages.save(.fixed(.french))

        languages.clear()

        #expect(languages.load() == .system)
        #expect(defaults.string(forKey: LanguagePreference.storageKey) == nil)
    }
}
