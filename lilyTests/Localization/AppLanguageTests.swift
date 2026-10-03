import Foundation
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
    @Test func aFixedLanguageReadsItsFolderAndKeepsTheUsersRegion() throws {
        let context = AppLocale.Context(language: .russian, current: Locale(identifier: "en_US"))

        #expect(context.locale.language.languageCode?.identifier == "ru")
        #expect(context.locale.region?.identifier == "US")
        #expect(context.bundle.bundlePath.hasSuffix("ru.lproj"))
    }

    @Test func theSystemChoiceReadsTheMainBundleInTheCurrentLocale() {
        let current = Locale(identifier: "fr_CA")
        let context = AppLocale.Context(language: nil, current: current)

        #expect(context.bundle == Bundle.main && context.locale == current && context.language == nil)
    }
}
