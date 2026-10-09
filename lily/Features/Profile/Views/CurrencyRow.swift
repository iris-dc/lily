import SwiftUI

/// The currency setting on Profile, for guests and users alike: a card with the current choice in a menu that offers
/// "System (<the region's code>)" and the currencies of `AppConfig.Currency.offered`, each with its name in the app's
/// language. A pick applies at once to the forms' price fields and the filter's cap. The menu holds a `Picker`, so its
/// items carry the checkmark, but the button is drawn here: a `Picker` button repeats the chosen item's full text, and
/// "PLN · Polish Zloty" wrapped the row to two lines (seen 2026-10-09), so the button shows the code alone.
struct CurrencyRow: View {
    let currency: CurrencyStore

    var body: some View {
        GlassCard {
            HStack(spacing: DesignTokens.Spacing.md) {
                Label(AppBranding.Settings.currency, systemImage: DesignTokens.Symbols.currency)
                Spacer()
                Menu {
                    Picker(AppBranding.Settings.currency, selection: selection) {
                        Text(systemTitle).tag(CurrencyPreference.system)
                        ForEach(AppConfig.Currency.offered, id: \.self) { code in
                            Text(verbatim: AppBranding.Settings.currencyChoice(code: code, name: Price.name(for: code)))
                                .tag(CurrencyPreference.fixed(code))
                        }
                    }
                } label: {
                    menuLabel
                }
                // The default menu button tints its whole label; plain keeps the text white and the chevrons accent.
                .menuStyle(.button)
                .buttonStyle(.plain)
                .accessibilityIdentifier(AccessibilityIdentifiers.profileCurrency)
            }
        }
    }

    private var systemTitle: String { AppBranding.Settings.systemCurrency(currency.systemCurrencyCode) }

    /// The code, or "System (EUR)"; the chevrons are the system picker's, so the row reads like the language row's.
    private var menuLabel: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            Text(verbatim: currency.preference.fixedCode ?? systemTitle)
                .lineLimit(1)
                .minimumScaleFactor(DesignTokens.Layout.menuLabelMinimumScale)
                .foregroundStyle(.primary)
            Image(systemName: DesignTokens.Symbols.menuChevron)
                .imageScale(.small)
                .fontWeight(.medium)
                .foregroundStyle(Color.lilyAccent)
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
