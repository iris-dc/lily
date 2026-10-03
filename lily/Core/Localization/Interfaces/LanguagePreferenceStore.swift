import Foundation

/// Where the language choice survives a relaunch.
protocol LanguagePreferenceStore {
    func load() -> LanguagePreference
    func save(_ preference: LanguagePreference)
    func clear()
}
