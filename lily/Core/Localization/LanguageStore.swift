import Foundation
import Observation

/// The user's language choice: loaded at launch, persisted on change, applied to `AppLocale` for every lookup and
/// published to the views, which re-render under the new language without a relaunch.
@Observable
final class LanguageStore {
    private(set) var preference: LanguagePreference
    /// The language the copy is in now: the fixed one, or the system's pick among the app's localizations.
    private(set) var language: AppLanguage
    /// The one context this store built and applied, so the store and `AppLocale` can never disagree.
    private(set) var context: AppLocale.Context

    private let store: any ChoiceStore<LanguagePreference>
    private let systemChoice: () -> AppLanguage
    private let apply: (AppLocale.Context) -> Void
    private let logger: any Logging

    /// `launchChoice` (the `-app-language` argument) is used for this run and never stored, so a screenshot run leaves
    /// the device's choice alone.
    init(store: any ChoiceStore<LanguagePreference>,
         launchChoice: AppLanguage? = nil,
         systemChoice: @escaping () -> AppLanguage = { AppLanguage.systemChoice() },
         apply: @escaping (AppLocale.Context) -> Void = AppLocale.set,
         logger: any Logging) {
        self.store = store
        self.systemChoice = systemChoice
        self.apply = apply
        self.logger = logger
        let preference = launchChoice.map(LanguagePreference.fixed) ?? store.load()
        self.preference = preference
        language = preference.resolved(systemChoice: systemChoice())
        context = Self.context(for: preference)
        apply(context)
        logger.info(.localization, "Language \(language.code) (\(Self.origin(of: preference)))")
    }

    /// The locale the views format with: the applied context's, the same values `AppLocale` formats with.
    var locale: Locale { context.locale }

    func select(_ preference: LanguagePreference) {
        guard preference != self.preference else { return }
        self.preference = preference
        store.save(preference)
        context = Self.context(for: preference)
        apply(context)
        language = preference.resolved(systemChoice: systemChoice())
        logger.info(.localization, "Language changed to \(language.code) (\(Self.origin(of: preference)))")
    }

    /// The one place a preference becomes the context `AppLocale` reads.
    private static func context(for preference: LanguagePreference) -> AppLocale.Context {
        AppLocale.Context(language: preference.fixedLanguage)
    }

    private static func origin(of preference: LanguagePreference) -> String {
        preference.fixedLanguage == nil ? "system" : "chosen"
    }
}
