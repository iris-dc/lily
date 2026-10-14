import Foundation

/// What the user chose on Profile: follow the system, or one language whatever the device speaks.
nonisolated enum LanguagePreference: StoredChoice {
    case system
    case fixed(AppLanguage)

    static let storageKey = AppConfig.Storage.Keys.languagePreference
    static let logCategory = LogCategory.localization

    /// How the choice is stored: the word `system`, or the language's code.
    var storedValue: String {
        switch self {
        case .system: AppConfig.Storage.systemChoiceValue
        case .fixed(let language): language.code
        }
    }

    /// The language the copy is in: the fixed one, or what the system picks.
    func resolved(systemChoice: AppLanguage) -> AppLanguage {
        switch self {
        case .system: systemChoice
        case .fixed(let language): language
        }
    }

    /// The fixed language, `nil` while following the system.
    var fixedLanguage: AppLanguage? {
        if case .fixed(let language) = self { return language }
        return nil
    }

    /// Nothing stored, or a value this build does not know, follows the system.
    init(storedValue: String?) {
        guard let storedValue, let language = AppLanguage(rawValue: storedValue) else {
            self = .system
            return
        }
        self = .fixed(language)
    }
}
