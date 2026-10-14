import Foundation

/// The currency prices are typed in, settled from the stored choice before the event screens are built.
extension AppDependencies {
    /// The stored currency choice, forgotten on a fresh start (`-reset-session`, decided and logged once by
    /// `makeDefault`) like the language choice, so UI tests and screenshot runs start from the device's region.
    static func makeCurrencyStore(startsFresh: Bool, defaults: UserDefaults, logger: any Logging) -> CurrencyStore {
        let store = UserDefaultsChoiceStore<CurrencyPreference>(defaults: defaults, logger: logger)
        if startsFresh { store.clear() }
        return CurrencyStore(store: store, logger: logger)
    }
}
