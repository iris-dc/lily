import Foundation

/// The copy for `key` in the app's language (`AppLocale`). The key is the English text, so a language without the
/// translation falls back to English, and a `String.LocalizationValue` interpolation becomes the catalog's `%lld` or
/// `%@` placeholder, picking the plural variant for the number it carries in the language's rules.
nonisolated func localized(_ key: String.LocalizationValue, comment: StaticString? = nil) -> String {
    let context = AppLocale.current
    return String(localized: key, bundle: context.bundle, locale: context.locale, comment: comment)
}
