import Foundation

nonisolated extension AppBranding {
    /// The settings on Profile: the language row and the choice that follows the device (the languages name
    /// themselves, `AppLanguage.nativeName`).
    enum Settings {
        static var language: String { localized("Language") }
        static var systemLanguage: String { localized("System") }
    }
}
