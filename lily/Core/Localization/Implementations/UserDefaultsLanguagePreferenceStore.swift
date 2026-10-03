import Foundation

/// The language choice in `UserDefaults`, under `AppConfig.Storage.Keys.languagePreference`.
final class UserDefaultsLanguagePreferenceStore: LanguagePreferenceStore {
    private let defaults: UserDefaults
    private let key = AppConfig.Storage.Keys.languagePreference

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> LanguagePreference {
        LanguagePreference(storedValue: defaults.string(forKey: key))
    }

    func save(_ preference: LanguagePreference) {
        defaults.set(preference.storedValue, forKey: key)
    }

    func clear() {
        defaults.removeObject(forKey: key)
    }
}
