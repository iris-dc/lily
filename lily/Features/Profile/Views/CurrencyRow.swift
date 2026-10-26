import SwiftUI

/// The currency setting on Profile, for guests and users alike: a card that drops down "System (<the region's code>)"
/// and the currencies of `AppConfig.Currency.offered`, each with its name in the app's language; the card shows the
/// code alone. A pick applies at once to the forms' price fields and the filter's cap.
struct CurrencyRow: View {
    let currency: CurrencyStore
    /// The app's locale names the currencies, and a language change re-renders the row through it.
    @Environment(\.locale) private var locale

    var body: some View {
        SettingsChoiceRow(title: AppBranding.Settings.currency,
                          systemImage: DesignTokens.Symbols.currency,
                          value: currency.preference.fixedCode ?? systemTitle,
                          identifier: AccessibilityIdentifiers.profileCurrency,
                          choices: choices,
                          selection: selection)
    }

    private var systemTitle: String { AppBranding.Settings.systemCurrency(currency.systemCurrencyCode) }

    private var choices: [SettingsChoice<CurrencyPreference>] {
        [SettingsChoice(value: .system, title: systemTitle)]
            + AppConfig.Currency.offered.map { code in
                let name = Price.name(for: code, locale: locale)
                return SettingsChoice(value: .fixed(code), title: AppBranding.Settings.currencyChoice(code: code, name: name))
            }
    }

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
