import Foundation

nonisolated extension AppBranding {
    /// The settings on Profile: the screen pushed from the profile root (language, currency, contact, the legal links
    /// and Sign out), and the language and currency choices that follow the device (the languages name themselves,
    /// `AppLanguage.nativeName`; the currencies are named by Foundation, `Price.name(for:)`).
    enum Settings {
        /// The screen's title and the link row on the profile root that opens it.
        static var title: String { localized("Settings") }
        /// Under the link row's title: what moved in here.
        static var rowSubtitle: String { localized("Language, currency and your account") }
        static var language: String { localized("Language") }
        static var systemLanguage: String { localized("System") }
        static var currency: String { localized("Currency") }
        /// "System (PLN)": following the region, which names this code.
        static func systemCurrency(_ code: String) -> String { localized("System (\(code))") }
        /// A currency in the menu: its code and its name, "PLN · Polish Zloty".
        static func currencyChoice(code: String, name: String) -> String { Groups.caption([code, name]) }
        /// Under the legal links: what each page holds.
        static var privacySubtitle: String { localized("How your data is handled") }
        static var termsSubtitle: String { localized("What you agree to") }
    }
}
