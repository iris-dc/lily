import SwiftUI

/// The optional details of a game: the description, who the host is looking for, the level and the price. The section
/// header and the first-issue footer stay with the form.
struct EventDetailsFields<Model: EventDraftEditing>: View {
    @Bindable var viewModel: Model

    private typealias Copy = AppBranding.Events.Create

    var body: some View {
        TextField(Copy.descriptionPlaceholder, text: $viewModel.draft.description, axis: .vertical)
            .textInputAutocapitalization(.sentences)
            .lineLimit(DesignTokens.Layout.multilineFieldLines)
        TextField(Copy.lookingForPlaceholder, text: $viewModel.draft.lookingFor)
            .textInputAutocapitalization(.sentences)
        SkillLevelPicker(selection: $viewModel.draft.skillLevel)
            .lilyMenuPicker()
        priceRow
    }

    /// Empty or zero means free. The draft holds the text and reads it as an amount on every change, so Create never
    /// races a pending commit of the decimal pad, which has no return key.
    private var priceRow: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            Text(Copy.price)
            Spacer()
            PriceAmountField(text: $viewModel.draft.priceText,
                             placeholder: Copy.pricePlaceholder,
                             currencyCode: viewModel.draft.currencyCode,
                             label: Copy.price,
                             identifier: AccessibilityIdentifiers.createPrice,
                             currencyIdentifier: AccessibilityIdentifiers.createPriceCurrency)
        }
    }
}
