import Foundation

/// The currency choice in `UserDefaults`, under `AppConfig.Storage.Keys.currencyPreference`.
final class UserDefaultsCurrencyPreferenceStore: CurrencyPreferenceStore {
    private let defaults: UserDefaults
    private let key = AppConfig.Storage.Keys.currencyPreference

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> CurrencyPreference {
        CurrencyPreference(storedValue: defaults.string(forKey: key))
    }

    func save(_ preference: CurrencyPreference) {
        defaults.set(preference.storedValue, forKey: key)
    }

    func clear() {
        defaults.removeObject(forKey: key)
    }
}
