import SwiftUI

/// The typed price of the filter sheet's cap and the form's price: a trailing decimal-pad field at `priceFieldWidth`
/// with the currency's symbol beside it, both findable by their identifiers. Given `currencySelection`, the symbol
/// becomes a compact menu over the offered currencies (the create wizard's Details step and the edit form, where the
/// host picks the event's own currency); without it the symbol stays the read-only fact it is on the filter's cap.
struct PriceAmountField: View {
    @Binding var text: String
    let placeholder: String
    let currencyCode: String
    /// What VoiceOver reads for the field, since the row's title is a separate `Text`.
    let label: String
    let identifier: String
    let currencyIdentifier: String
    /// The host's inline currency choice; `nil` keeps the symbol a plain fact.
    let currencySelection: Binding<String>?
    /// The panel's capsule focuses the field by a tap on any of it; a form row leaves focus to the field itself.
    let focus: FocusState<Bool>.Binding?

    init(text: Binding<String>,
         placeholder: String,
         currencyCode: String,
         label: String,
         identifier: String,
         currencyIdentifier: String,
         currencySelection: Binding<String>? = nil,
         focus: FocusState<Bool>.Binding? = nil) {
        _text = text
        self.placeholder = placeholder
        self.currencyCode = currencyCode
        self.label = label
        self.identifier = identifier
        self.currencyIdentifier = currencyIdentifier
        self.currencySelection = currencySelection
        self.focus = focus
    }

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            focusable(TextField(placeholder, text: $text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing))
                .frame(width: DesignTokens.Layout.priceFieldWidth)
                .accessibilityIdentifier(identifier)
                .accessibilityLabel(label)
            currencyMark
        }
    }

    private var symbol: some View {
        Text(Price.symbol(for: currencyCode))
            .foregroundStyle(.secondary)
            .fixedSize()
    }

    /// The symbol alone, or the compact menu over the offered currencies when the caller hands the choice over; the
    /// identifier stays on whichever shape renders, so a reader finds one element either way.
    @ViewBuilder private var currencyMark: some View {
        if let currencySelection {
            Menu {
                Picker(AppBranding.Settings.currency, selection: currencySelection) {
                    ForEach(offeredCodes, id: \.self) { code in
                        Text(AppBranding.Settings.currencyChoice(code: code, name: Price.name(for: code))).tag(code)
                    }
                }
            } label: {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    symbol
                    Image(systemName: DesignTokens.Symbols.currencyMenu)
                        .font(LilyTheme.Fonts.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
            }
            .accessibilityIdentifier(currencyIdentifier)
        } else {
            symbol
                .accessibilityIdentifier(currencyIdentifier)
        }
    }

    /// The Profile row's codes, led by the current one when an edited event carries a currency the row no longer
    /// offers, so the menu always shows the choice in force.
    private var offeredCodes: [String] {
        let offered = AppConfig.Currency.offered
        guard let code = currencySelection?.wrappedValue, !offered.contains(code) else { return offered }
        return [code] + offered
    }

    @ViewBuilder
    private func focusable(_ field: some View) -> some View {
        if let focus {
            field.focused(focus)
        } else {
            field
        }
    }
}

#Preview {
    @Previewable @State var text = ""
    ContentScreen {
        PriceAmountField(text: $text,
                         placeholder: AppBranding.Events.Create.pricePlaceholder,
                         currencyCode: "EUR",
                         label: AppBranding.Events.Create.price,
                         identifier: AccessibilityIdentifiers.createPrice,
                         currencyIdentifier: AccessibilityIdentifiers.createPriceCurrency)
    }
}
