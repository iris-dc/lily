import Foundation
import Observation

/// The user's language choice: loaded at launch, persisted on change, applied to `AppLocale` for every lookup and
/// published to the views, which re-render under the new language without a relaunch.
@Observable
final class LanguageStore {
    private(set) var preference: LanguagePreference
    /// The language the copy is in now: the fixed one, or the system's pick among the app's localizations.
    private(set) var language: AppLanguage

    private let store: any LanguagePreferenceStore
    private let systemChoice: () -> AppLanguage
    private let apply: (AppLanguage?) -> Void
    private let logger: any Logging

    /// `launchChoice` (the `-app-language` argument) is used for this run and never stored, so a screenshot run leaves
    /// the device's choice alone.
    init(store: any LanguagePreferenceStore,
         launchChoice: AppLanguage? = nil,
         systemChoice: @escaping () -> AppLanguage = { AppLanguage.systemChoice() },
         apply: @escaping (AppLanguage?) -> Void = AppLocale.set,
         logger: any Logging) {
        self.store = store
        self.systemChoice = systemChoice
        self.apply = apply
        self.logger = logger
        let preference = launchChoice.map(LanguagePreference.fixed) ?? store.load()
        self.preference = preference
        language = preference.resolved(systemChoice: systemChoice())
        apply(preference.fixedLanguage)
        logger.info(.localization, "Language \(language.code) (\(Self.origin(of: preference)))")
    }

    /// The locale the views format with: the fixed language in the user's region, or the device's own while the system
    /// chooses (the same values `AppLocale` formats with).
    var locale: Locale {
        preference.fixedLanguage.map { AppLocale.Context.locale(for: $0) } ?? .autoupdatingCurrent
    }

    func select(_ preference: LanguagePreference) {
        guard preference != self.preference else { return }
        self.preference = preference
        store.save(preference)
        apply(preference.fixedLanguage)
        language = preference.resolved(systemChoice: systemChoice())
        logger.info(.localization, "Language changed to \(language.code) (\(Self.origin(of: preference)))")
    }

    private static func origin(of preference: LanguagePreference) -> String {
        preference.fixedLanguage == nil ? "system" : "chosen"
    }
}
