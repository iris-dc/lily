import SwiftUI

/// The currency setting on Profile, for guests and users alike: a card that opens a menu of "System (<the region's
/// code>)" and the currencies of `AppConfig.Currency.offered`, each with its name in the app's language; the card
/// shows the code alone. A pick applies at once to the forms' price fields and the filter's cap.
struct CurrencyRow: View {
    let currency: CurrencyStore
    /// The app's locale names the currencies, and a language change re-renders the row through it.
    @Environment(\.locale) private var locale

    var body: some View {
        SettingsMenuRow(title: AppBranding.Settings.currency,
                        systemImage: DesignTokens.Symbols.currency,
                        value: currency.preference.fixedCode ?? systemTitle,
                        identifier: AccessibilityIdentifiers.profileCurrency) {
            Picker(AppBranding.Settings.currency, selection: selection) {
                Text(systemTitle).tag(CurrencyPreference.system)
                ForEach(AppConfig.Currency.offered, id: \.self) { code in
                    Text(verbatim: AppBranding.Settings.currencyChoice(code: code, name: Price.name(for: code, locale: locale)))
                        .tag(CurrencyPreference.fixed(code))
                }
            }
        }
    }

    private var systemTitle: String { AppBranding.Settings.systemCurrency(currency.systemCurrencyCode) }

    private var selection: Binding<CurrencyPreference> {
        Binding(get: { currency.preference }, set: { currency.select($0) })
    }
}

#Preview {
    ContentScreen {
        CurrencyRow(currency: AppDependencies.makeMock().currency)
            .padding(DesignTokens.Layout.screenMargin)
    }
}
