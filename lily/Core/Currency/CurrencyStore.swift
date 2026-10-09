import Foundation
import Observation

/// The currency the user types prices in and judges the price cap in: the one chosen on Profile, else the one the
/// device's region uses (PLN in Poland, EUR in Spain, USD in the US), else the app's default. Loaded at launch,
/// persisted on change and published to the views. Prices on events keep their own currency whatever this says;
/// nothing is ever converted.
@Observable
final class CurrencyStore {
    private(set) var preference: CurrencyPreference

    private let store: any CurrencyPreferenceStore
    private let systemChoice: () -> String?
    private let logger: any Logging

    /// `systemChoice` answers the region's currency code, `nil` where the region names none (then the default applies).
    init(store: any CurrencyPreferenceStore,
         systemChoice: @escaping () -> String? = { AppLocale.locale.currency?.identifier },
         logger: any Logging) {
        self.store = store
        self.systemChoice = systemChoice
        self.logger = logger
        preference = store.load()
        logger.info(.currency, "Currency \(currencyCode) (\(Self.origin(of: preference)))")
    }

    /// The code in force now.
    var currencyCode: String { preference.resolved(systemCode: systemCurrencyCode) }

    /// What "System" means on this device.
    var systemCurrencyCode: String { systemChoice() ?? AppConfig.Currency.defaultCode }

    func select(_ preference: CurrencyPreference) {
        guard preference != self.preference else { return }
        self.preference = preference
        store.save(preference)
        logger.info(.currency, "Currency changed to \(currencyCode) (\(Self.origin(of: preference)))")
    }

    private static func origin(of preference: CurrencyPreference) -> String {
        preference.fixedCode == nil ? "system" : "chosen"
    }
}
