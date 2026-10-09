import Foundation

nonisolated extension AppConfig {
    enum Currency {
        /// The currency when the device's region names none, and the one the mock fixtures (Berlin) are priced in.
        static let defaultCode = "EUR"
        /// The currencies the Profile row offers by hand, besides following the region; a stored choice outside this
        /// list falls back to the region. ISO 4217 codes, as the backend stores them on each event.
        static let offered = ["EUR", "USD", "GBP", "PLN", "CHF", "CZK", "HUF", "RON", "SEK", "NOK", "DKK", "UAH", "CAD", "BRL"]
    }
}

nonisolated extension AppConfig.Storage.Keys {
    /// The currency chosen on Profile: an ISO 4217 code, or `system`.
    static let currencyPreference = "lily.currency.preference"
}
