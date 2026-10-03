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

    /// How an amount is shown in and read from an input field (the price cap, the price of a new game): the user's
    /// locale, at most two decimals.
    static let inputFormat = Decimal.FormatStyle.number.precision(.fractionLength(0...2))

    /// Reads typed text as an amount, locale-aware ("6,5" and "6.5"); empty, unreadable or negative text is no amount.
    static func parseAmount(_ text: String, locale: Locale = AppLocale.locale) -> Decimal? {
        guard let amount = try? inputFormat.locale(locale).parseStrategy.parse(text), amount >= 0 else { return nil }
        return amount
    }

    private var isWholeAmount: Bool {
        var value = amount
        var whole = Decimal()
        NSDecimalRound(&whole, &value, 0, .down)
        return whole == amount
    }
}
