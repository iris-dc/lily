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
        #expect(line == "Новая игра от Marta: Sunset 5-a-side")
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
