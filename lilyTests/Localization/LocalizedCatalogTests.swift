import Foundation
import Testing
@testable import lily

/// The catalog as the build compiled it into the app bundle: one folder per language, every key in every one of them,
/// and the lookups the app makes (`String(localized:bundle:locale:)`) answering in the right language and plural form.
struct LocalizedCatalogTests {
    private static let table = "Localizable"

    @Test func everyLanguageShipsAFolderAndEveryKey() throws {
        var keysByLanguage: [AppLanguage: Set<String>] = [:]
        for language in AppLanguage.allCases where language != .english {
            let folder = try #require(Bundle.main.path(forResource: language.code, ofType: "lproj"), "\(language.code) folder")
            keysByLanguage[language] = Self.keys(in: folder)
        }
        let allKeys = keysByLanguage.values.reduce(into: Set<String>()) { $0.formUnion($1) }
        #expect(allKeys.count > 300)
        for (language, keys) in keysByLanguage {
            let missing = allKeys.subtracting(keys)
            #expect(missing.isEmpty, "\(language.code) lacks \(missing.sorted())")
        }
    }

    @Test func aFixedLanguageAnswersInItsWordsAndPluralForms() throws {
        let russian = AppLocale.Context(language: .russian, current: { Locale(identifier: "en_US") })
        #expect(String(localized: "Sign in", bundle: russian.bundle, locale: russian.locale) == "Войти")
        #expect(String(localized: "\(1) spots left", bundle: russian.bundle, locale: russian.locale) == "Осталось 1 место")
        #expect(String(localized: "\(2) spots left", bundle: russian.bundle, locale: russian.locale) == "Осталось 2 места")
        #expect(String(localized: "\(5) spots left", bundle: russian.bundle, locale: russian.locale) == "Осталось 5 мест")
        #expect(String(localized: "\(21) spots left", bundle: russian.bundle, locale: russian.locale) == "Осталось 21 место")

        let polish = AppLocale.Context(language: .polish)
        #expect(String(localized: "\(2) members", bundle: polish.bundle, locale: polish.locale) == "2 członków")
        #expect(String(localized: "\(1) members", bundle: polish.bundle, locale: polish.locale) == "1 członek")
    }

    @Test func englishKeepsItsOneFormsAndAnUnknownKeyFallsBackToItself() {
        let english = AppLocale.Context(language: .english)
        #expect(String(localized: "\(1) spots left", bundle: english.bundle, locale: english.locale) == "1 spot left")
        #expect(String(localized: "\(3) spots left", bundle: english.bundle, locale: english.locale) == "3 spots left")
        let russian = AppLocale.Context(language: .russian)
        #expect(String(localized: "Not in the catalog", bundle: russian.bundle, locale: russian.locale) == "Not in the catalog")
    }

    @Test func aReorderedTranslationFormatsItsArgumentsInPlace() {
        let russian = AppLocale.Context(language: .russian)
        let line = String(localized: "\("Marta") created \("Sunset 5-a-side")", bundle: russian.bundle, locale: russian.locale)
        #expect(line == "Новое событие от Marta: Sunset 5-a-side")
    }

    /// A key that names a role carries the English it shows, so the lookup never answers the key itself.
    @Test func aRoleKeyShowsItsEnglishValueAndItsOwnTranslation() {
        let english = AppLocale.Context(language: .english)
        #expect(String(localized: "Message (verb)", bundle: english.bundle, locale: english.locale) == "Message")
        #expect(String(localized: "Any (price)", bundle: english.bundle, locale: english.locale) == "Any")
        #expect(String(localized: "Not allowed (draws)", bundle: english.bundle, locale: english.locale) == "Not allowed")
        let russian = AppLocale.Context(language: .russian)
        #expect(String(localized: "Message (verb)", bundle: russian.bundle, locale: russian.locale) == "Написать")
        #expect(String(localized: "Any (price)", bundle: russian.bundle, locale: russian.locale) == "Любая")
        #expect(String(localized: "Not allowed (draws)", bundle: russian.bundle, locale: russian.locale) == "Не разрешены")
    }

    /// The bare keys are the nouns: "Message" is the composer's placeholder, "Any" the distance menu's neuter.
    @Test func theNounKeysKeptTheirTranslations() {
        let russian = AppLocale.Context(language: .russian)
        #expect(String(localized: "Message", bundle: russian.bundle, locale: russian.locale) == "Сообщение")
        #expect(String(localized: "Any", bundle: russian.bundle, locale: russian.locale) == "Любое")
    }

    /// One key for the whole toggle, so a language orders the question and the action its own way.
    @Test func theSignInToggleIsOneSentencePerLanguage() {
        let russian = AppLocale.Context(language: .russian)
        let sentence = String(localized: "Already have an account? Sign in", bundle: russian.bundle, locale: russian.locale)
        #expect(sentence == "Уже есть аккаунт? Войти")
        let english = AppLocale.Context(language: .english)
        let englishSentence = String(localized: "Already have an account? Sign in",
                                     bundle: english.bundle,
                                     locale: english.locale)
        #expect(englishSentence == "Already have an account? Sign in")
    }

    /// The usage descriptions the build sets (project.pbxproj, the three app configurations) reach the generated plist
    /// in English and every other language's `InfoPlist.strings`, compiled from `InfoPlist.xcstrings`.
    @Test func everyUsageDescriptionTheBuildSetsIsInEveryLanguagesInfoPlistStrings() throws {
        let usageKeys = ["NSCameraUsageDescription", "NSLocationWhenInUseUsageDescription", "NSPhotoLibraryAddUsageDescription"]
        let info = try #require(Bundle.main.infoDictionary)
        for key in usageKeys {
            let english = try #require(info[key] as? String, "\(key) in the plist")
            #expect(!english.isEmpty, "\(key) is empty in the plist")
        }
        for language in AppLanguage.allCases where language != .english {
            let folder = try #require(Bundle.main.path(forResource: language.code, ofType: "lproj"), "\(language.code) folder")
            let path = (folder as NSString).appendingPathComponent("InfoPlist.strings")
            let strings = try #require(NSDictionary(contentsOfFile: path) as? [String: String],
                                       "\(language.code) InfoPlist.strings")
            for key in usageKeys {
                #expect(!(strings[key] ?? "").isEmpty, "\(language.code) lacks \(key)")
            }
        }
    }

    /// The constant-count hints agree with the numbers they show: 2 and 3 take the few form in Ukrainian ("символи",
    /// not the flat "символів" they had), 1 the one form, and the Polish and Russian forms follow suit.
    @Test func theNameAndTournamentLimitHintsAgreeWithTheirCounts() {
        #expect(Self.text("Give the team a name of at least \(2) characters", in: .ukrainian).hasSuffix("2 символи"))
        #expect(Self.text("Give the tournament a name of at least \(3) characters", in: .ukrainian).hasSuffix("3 символи"))
        #expect(Self.text("Keep the team name under \(1) characters", in: .ukrainian).hasSuffix("1 символа"))
        #expect(Self.text("Keep the team name under \(3) characters", in: .polish).hasSuffix("3 znaki"))
        let polish = Self.text("You can run at most \(2) open tournaments. Finish or cancel one first.", in: .polish)
        #expect(polish.contains("2 otwarte turnieje"))
        let russian = Self.text("You can run at most \(1) open tournaments. Finish or cancel one first.", in: .russian)
        #expect(russian.contains("1 турнира"))
    }

    /// "Between %lld and %lld entries" (64 and 12), "Between %lld and %lld players" (200), "Between %lld and %lld players
    /// per team" (11) and "Pictures can be up to ... %lld minutes ..." (3) stay flat: ru, uk and pl put the noun after the
    /// last number in the genitive, which is right for every value except 1 and, in ru/uk, 21/31/... A limit that
    /// breaks this needs plural forms (positional, through `substitutions`) before it ships.
    @Test func theRangeHintsKeepTheGenitiveForTheConstantsTheyShow() {
        let shown = [AppConfig.Tournaments.entriesRange.upperBound,
                     AppConfig.Tournaments.maxEntriesRoundRobin,
                     AppConfig.Events.Creation.capacityRange.upperBound,
                     AppConfig.Tournaments.teamSizeRange.upperBound,
                     Int(AppConfig.Chat.Attachments.videoMaxDurationSeconds) / 60]
        for count in shown {
            #expect(count != 1 && (count % 10 != 1 || count % 100 == 11), "\(count) needs plural forms in the catalog")
        }
    }

    private static func text(_ key: String.LocalizationValue, in language: AppLanguage) -> String {
        let context = AppLocale.Context(language: language)
        return String(localized: key, bundle: context.bundle, locale: context.locale)
    }

    /// The keys of a folder's `Localizable.strings` and `Localizable.stringsdict` (plurals land in the latter).
    private static func keys(in folder: String) -> Set<String> {
        var keys = Set<String>()
        for file in ["\(table).strings", "\(table).stringsdict"] {
            let path = (folder as NSString).appendingPathComponent(file)
            if let dictionary = NSDictionary(contentsOfFile: path) as? [String: Any] {
                keys.formUnion(dictionary.keys)
            }
        }
        return keys
    }
}
