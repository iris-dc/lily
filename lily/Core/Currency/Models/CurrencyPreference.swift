import Foundation

/// What the user chose on Profile for the currency prices are typed in: follow the device's region, or one currency
/// whatever the region says.
nonisolated enum CurrencyPreference: Hashable, Sendable {
    case system
    case fixed(String)

    /// How the choice is stored: the word `system`, or the ISO 4217 code.
    var storedValue: String {
        switch self {
        case .system: Self.systemStoredValue
        case .fixed(let code): code
        }
    }

    /// The code in force: the fixed one, or what the region names.
    func resolved(systemCode: String) -> String {
        switch self {
        case .system: systemCode
        case .fixed(let code): code
        }
    }

    /// The fixed code, `nil` while following the region.
    var fixedCode: String? {
        if case .fixed(let code) = self { return code }
        return nil
    }

    /// Nothing stored, or a code this build no longer offers, follows the region.
    init(storedValue: String?) {
        guard let storedValue, AppConfig.Currency.offered.contains(storedValue) else {
            self = .system
            return
        }
        self = .fixed(storedValue)
    }

    private static let systemStoredValue = "system"
}
