import Foundation

nonisolated extension AppBranding {
    /// The settings on Profile: the language and currency rows and the choices that follow the device (the languages
    /// name themselves, `AppLanguage.nativeName`; the currencies are named by Foundation, `Price.name(for:)`).
    enum Settings {
        static var language: String { localized("Language") }
        static var systemLanguage: String { localized("System") }
        static var currency: String { localized("Currency") }
        /// "System (PLN)": following the region, which names this code.
        static func systemCurrency(_ code: String) -> String { localized("System (\(code))") }
        /// A currency in the menu: its code and its name, "PLN · Polish Zloty".
        static func currencyChoice(code: String, name: String) -> String { "\(code) · \(name)" }
    }
}
