import Foundation

/// The languages the app ships copy in, as `Localizable.xcstrings` lists them. English is the source language and the
/// fallback for every device language the catalog does not cover.
nonisolated enum AppLanguage: String, CaseIterable, Codable, Hashable, Sendable {
    case english = "en"
    case russian = "ru"
    case spanish = "es"
    case french = "fr"
    case ukrainian = "uk"
    case polish = "pl"
    case portuguese = "pt"

    static let fallback = AppLanguage.english

    /// The tag the catalog's `.lproj` folder, the device registration and the sign-up mail carry.
    var code: String { rawValue }

    /// The language's own name for itself, which is how a language list reads whatever language is on.
    var nativeName: String {
        switch self {
        case .english: "English"
        case .russian: "Русский"
        case .spanish: "Español"
        case .french: "Français"
        case .ukrainian: "Українська"
        case .polish: "Polski"
        case .portuguese: "Português"
        }
    }

    /// The language the system picks for the app: the first of the app's localizations the user prefers, as
    /// `Bundle.preferredLocalizations` ranks them (the per-app language in Settings included), else the fallback.
    static func systemChoice(preferredLocalizations: [String] = Bundle.main.preferredLocalizations) -> AppLanguage {
        preferredLocalizations.lazy.compactMap(AppLanguage.init(localization:)).first ?? fallback
    }

    /// `pt-BR` and `pt_PT` are Portuguese: a region never selects a different catalog.
    init?(localization: String) {
        let language = Locale(identifier: localization).language.languageCode?.identifier ?? localization
        self.init(rawValue: language.lowercased())
    }
}
