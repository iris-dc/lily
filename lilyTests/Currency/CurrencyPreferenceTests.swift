import Foundation
import Testing
@testable import lily

struct CurrencyPreferenceTests {
    @Test func storesTheWordSystemOrTheCode() {
        #expect(CurrencyPreference.system.storedValue == "system")
        #expect(CurrencyPreference.fixed("PLN").storedValue == "PLN")
    }

    @Test func readsBackWhatItStored() {
        #expect(CurrencyPreference(storedValue: CurrencyPreference.system.storedValue) == .system)
        #expect(CurrencyPreference(storedValue: CurrencyPreference.fixed("USD").storedValue) == .fixed("USD"))
    }

    @Test func nothingStoredOrACodeNoLongerOfferedFollowsTheSystem() {
        #expect(CurrencyPreference(storedValue: nil) == .system)
        #expect(CurrencyPreference(storedValue: "") == .system)
        #expect(CurrencyPreference(storedValue: "XXX") == .system, "a code the menu does not offer would leave the picker blank")
        #expect(CurrencyPreference(storedValue: "pln") == .system, "codes are stored upper-case, as the backend takes them")
    }

    @Test func resolvesToTheFixedCodeOrTheSystems() {
        #expect(CurrencyPreference.system.resolved(systemCode: "GBP") == "GBP")
        #expect(CurrencyPreference.fixed("CHF").resolved(systemCode: "GBP") == "CHF")
        #expect(CurrencyPreference.system.fixedCode == nil && CurrencyPreference.fixed("CHF").fixedCode == "CHF")
    }

    @Test func everyOfferedCurrencyIsAnISOCodeFoundationKnows() {
        let known = Set(Locale.Currency.isoCurrencies.map(\.identifier))
        for code in AppConfig.Currency.offered {
            #expect(known.contains(code), "\(code)")
            #expect(code.count == 3 && code == code.uppercased(), "\(code)")
        }
        #expect(Set(AppConfig.Currency.offered).count == AppConfig.Currency.offered.count, "no duplicates")
        #expect(AppConfig.Currency.offered.contains(AppConfig.Currency.defaultCode))
    }
}
