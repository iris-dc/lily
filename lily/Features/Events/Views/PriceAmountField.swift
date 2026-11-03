import SwiftUI

/// The typed price of the filter panel's cap and the form's price: a trailing decimal-pad field at `priceFieldWidth`
/// with the currency's symbol beside it, both findable by their identifiers.
struct PriceAmountField: View {
    @Binding var text: String
    let placeholder: String
    let currencyCode: String
    /// What VoiceOver reads for the field, since the row's title is a separate `Text`.
    let label: String
    let identifier: String
    let currencyIdentifier: String
    /// The panel's capsule focuses the field by a tap on any of it; a form row leaves focus to the field itself.
    let focus: FocusState<Bool>.Binding?

    init(text: Binding<String>,
         placeholder: String,
         currencyCode: String,
         label: String,
         identifier: String,
         currencyIdentifier: String,
         focus: FocusState<Bool>.Binding? = nil) {
        _text = text
        self.placeholder = placeholder
        self.currencyCode = currencyCode
        self.label = label
        self.identifier = identifier
        self.currencyIdentifier = currencyIdentifier
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
            Text(Price.symbol(for: currencyCode))
                .foregroundStyle(.secondary)
                .fixedSize()
                .accessibilityIdentifier(currencyIdentifier)
        }
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
