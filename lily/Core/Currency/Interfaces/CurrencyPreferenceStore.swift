import Foundation

/// Where the currency choice survives a relaunch.
protocol CurrencyPreferenceStore {
    func load() -> CurrencyPreference
    func save(_ preference: CurrencyPreference)
    func clear()
}
