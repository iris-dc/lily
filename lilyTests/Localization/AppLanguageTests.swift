import Foundation
import Synchronization
import Testing
@testable import lily

struct AppLanguageTests {
    @Test func theSystemChoiceIsTheFirstPreferredLocalizationTheAppShips() {
        #expect(AppLanguage.systemChoice(preferredLocalizations: ["ru", "en"]) == .russian)
        #expect(AppLanguage.systemChoice(preferredLocalizations: ["pt-BR", "ru"]) == .portuguese)
        #expect(AppLanguage.systemChoice(preferredLocalizations: ["en"]) == .english)
    }

    @Test func nothingTheAppShipsFallsBackToEnglish() {
        #expect(AppLanguage.systemChoice(preferredLocalizations: []) == .english)
        #expect(AppLanguage.systemChoice(preferredLocalizations: ["de", "ja"]) == .english)
    }

    @Test func aRegionNeverSelectsADifferentCatalog() {
        #expect(AppLanguage(localization: "pt_PT") == .portuguese)
        #expect(AppLanguage(localization: "ru-RU") == .russian)
        #expect(AppLanguage(localization: "uk") == .ukrainian)
        #expect(AppLanguage(localization: "de") == nil)
    }

    @Test func everyLanguageNamesItselfOnce() {
        let names = AppLanguage.allCases.map(\.nativeName)
        #expect(Set(names).count == names.count)
        #expect(AppLanguage.russian.nativeName == "Русский" && AppLanguage.ukrainian.nativeName == "Українська")
    }
}

struct LanguagePreferenceTests {
    @Test func theStoredValueRoundTrips() {
        for language in AppLanguage.allCases {
            let preference = LanguagePreference.fixed(language)
            #expect(LanguagePreference(storedValue: preference.storedValue) == preference)
        }
        #expect(LanguagePreference(storedValue: LanguagePreference.system.storedValue) == .system)
    }

    @Test func nothingStoredOrAnUnknownValueFollowsTheSystem() {
        #expect(LanguagePreference(storedValue: nil) == .system)
        #expect(LanguagePreference(storedValue: "klingon") == .system)
    }

    @Test func aFixedLanguageWinsOverTheSystemChoice() {
        #expect(LanguagePreference.system.resolved(systemChoice: .polish) == .polish)
        #expect(LanguagePreference.fixed(.french).resolved(systemChoice: .polish) == .french)
        #expect(LanguagePreference.system.fixedLanguage == nil && LanguagePreference.fixed(.spanish).fixedLanguage == .spanish)
    }
}

struct AppLocaleContextTests {
    private final class BundleToken {}

    @Test func aFixedLanguageReadsItsFolderAndKeepsTheUsersRegion() throws {
        let context = AppLocale.Context(language: .russian, current: { Locale(identifier: "en_US") })

        #expect(context.locale.language.languageCode?.identifier == "ru")
        #expect(context.locale.region?.identifier == "US")
        #expect(context.bundle.bundlePath.hasSuffix("ru.lproj"))
    }

    @Test func theSystemChoiceReadsTheMainBundleInTheCurrentLocale() {
        let current = Locale(identifier: "fr_CA")
        let context = AppLocale.Context(language: nil, current: { current })

        #expect(context.bundle == Bundle.main && context.locale == current && context.language == nil)
    }

    @Test func aRegionChangeIsSeenWithoutARelaunch() {
        let region = Mutex(Locale(identifier: "ru_US"))
        let fixed = AppLocale.Context(language: .russian, current: { region.withLock { $0 } })
        let system = AppLocale.Context(language: nil, current: { region.withLock { $0 } })
        #expect(fixed.locale.region?.identifier == "US" && fixed.locale.currency?.identifier == "USD")

        region.withLock { $0 = Locale(identifier: "ru_PL") }

        #expect(fixed.locale.region?.identifier == "PL" && fixed.locale.currency?.identifier == "PLN")
        #expect(fixed.locale.language.languageCode?.identifier == "ru")
        #expect(system.locale.identifier == Locale(identifier: "ru_PL").identifier)
    }

    /// The test bundle carries no `.lproj`, so the folder lookup answers nil and the copy comes from the main bundle.
    @Test func aLanguageWithoutAFolderFallsBackToTheMainBundle() {
        let context = AppLocale.Context(language: .russian,
                                        mainBundle: Bundle(for: BundleToken.self),
                                        current: { Locale(identifier: "en_US") })

        #expect(context.bundle == Bundle.main && context.language == .russian)
        #expect(context.locale.language.languageCode?.identifier == "ru")
    }
}
