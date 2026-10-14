import Foundation

/// What one participant pays. Absent on an event means free.
nonisolated struct Price: Hashable, Codable, Sendable {
    let amount: Decimal
    let currencyCode: String

    var isFree: Bool { amount <= 0 }

    /// "Free" for a zero amount; whole amounts without minor units ("€5"), anything else in the currency's usual form
    /// ("€7.50"), in the app's language and the user's region.
    var text: String { text(in: AppLocale.locale) }

    func text(in locale: Locale) -> String {
        guard !isFree else { return AppBranding.Events.free }
        let currency = Decimal.FormatStyle.Currency(code: currencyCode, locale: locale)
        return isWholeAmount ? amount.formatted(currency.precision(.fractionLength(0))) : amount.formatted(currency)
    }

    /// The symbol the user's locale uses for a currency code ("€" for EUR), for input fields.
    static func symbol(for currencyCode: String, locale: Locale = AppLocale.locale) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = locale
        formatter.currencyCode = currencyCode
        return formatter.currencySymbol ?? currencyCode
    }

    /// The name the user's locale gives a currency code ("Polish Zloty" for PLN), for the Profile menu; the code when
    /// the locale has none.
    static func name(for currencyCode: String, locale: Locale = AppLocale.locale) -> String {
        locale.localizedString(forCurrencyCode: currencyCode) ?? currencyCode
    }

    /// How an amount is shown in and read from an input field (the price cap, the price of a new game): at most two
    /// decimals and no grouping, because the same text is read back whole, and a grouping separator would be refused
    /// here and read as a decimal one in another locale.
    static let inputFormat = Decimal.FormatStyle.number.precision(.fractionLength(0...2)).grouping(.never)

    /// The text an input field is seeded with (an edited game's price, a cap set by the chip or Reset): the
    /// counterpart of `parseAmount`, in the same locale, so what is seeded reads back unchanged.
    static func inputText(_ amount: Decimal, locale: Locale = AppLocale.locale) -> String {
        amount.formatted(inputFormat.locale(locale))
    }

    /// Reads typed text as an amount. The whole trimmed text must be one number in the locale's form, so a stray or
    /// foreign separator, a symbol or a code is unreadable rather than misread (a lenient parse reads en_US "5,50" as
    /// 550); empty, unreadable or negative text is no amount.
    static func parseAmount(_ text: String, locale: Locale = AppLocale.locale) -> Decimal? {
        let trimmed = text.trimmed
        guard let amount = trimmed.wholeMatch(of: inputFormat.locale(locale))?.output, amount >= 0 else { return nil }
        return amount
    }

    private var isWholeAmount: Bool {
        var value = amount
        var whole = Decimal()
        NSDecimalRound(&whole, &value, 0, .down)
        return whole == amount
    }
}
