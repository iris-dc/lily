import Foundation

/// What one participant pays. Absent on an event means free.
nonisolated struct Price: Hashable, Codable, Sendable {
    let amount: Decimal
    let currencyCode: String

    var isFree: Bool { amount <= 0 }

    /// "Free" for a zero amount; whole amounts without minor units ("€5"), anything else in the currency's usual form
    /// ("€7.50"), in the user's locale.
    var text: String { text(in: .current) }

    func text(in locale: Locale) -> String {
        guard !isFree else { return AppBranding.Events.free }
        let currency = Decimal.FormatStyle.Currency(code: currencyCode, locale: locale)
        return isWholeAmount ? amount.formatted(currency.precision(.fractionLength(0))) : amount.formatted(currency)
    }

    /// The symbol the user's locale uses for a currency code ("€" for EUR), for input fields.
    static func symbol(for currencyCode: String, locale: Locale = .current) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = locale
        formatter.currencyCode = currencyCode
        return formatter.currencySymbol ?? currencyCode
    }

    private var isWholeAmount: Bool {
        var value = amount
        var whole = Decimal()
        NSDecimalRound(&whole, &value, 0, .down)
        return whole == amount
    }
}
