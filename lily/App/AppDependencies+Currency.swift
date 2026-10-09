import Foundation

/// The currency prices are typed in, settled from the stored choice before the event screens are built.
extension AppDependencies {
    /// The stored currency choice, forgotten by `-reset-session` like the language choice, so UI tests and screenshot
    /// runs start from the device's region.
    static func makeCurrencyStore(arguments: [String], defaults: UserDefaults, logger: any Logging) -> CurrencyStore {
        let store = UserDefaultsCurrencyPreferenceStore(defaults: defaults)
        if arguments.contains(AppConfig.LaunchArguments.resetSession) { store.clear() }
        return CurrencyStore(store: store, logger: logger)
    }
}
