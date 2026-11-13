import SwiftUI

/// The optional details of a game: the description, who the host is looking for, the level and the price. The section
/// header and the first-issue footer stay with the form. Each leavable field wears the shared marker below it, as on
/// the wizard's Details step; the level picker stays unmarked (its "Any level" value already says it).
struct EventDetailsFields<Model: EventDraftEditing>: View {
    @Bindable var viewModel: Model

    private typealias Copy = AppBranding.Events.Create

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            TextField(Copy.descriptionPlaceholder, text: $viewModel.draft.description, axis: .vertical)
                .textInputAutocapitalization(.sentences)
                .lineLimit(DesignTokens.Layout.multilineFieldLines)
            OptionalMarker()
        }
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            TextField(Copy.lookingForPlaceholder, text: $viewModel.draft.lookingFor)
                .textInputAutocapitalization(.sentences)
            OptionalMarker()
        }
        SkillLevelPicker(selection: $viewModel.draft.skillLevel)
            .lilyMenuPicker()
        priceRow
    }

    /// Empty or zero means free. The draft holds the text and reads it as an amount on every change, so Create never
    /// races a pending commit of the decimal pad, which has no return key. The symbol is the inline currency menu,
    /// as on the wizard's Details step, so a host edits the event's own currency here too.
    private var priceRow: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            HStack(spacing: DesignTokens.Spacing.xs) {
                Text(Copy.price)
                Spacer()
                PriceAmountField(text: $viewModel.draft.priceText,
                                 placeholder: Copy.pricePlaceholder,
                                 currencyCode: viewModel.draft.currencyCode,
                                 label: Copy.price,
                                 identifier: AccessibilityIdentifiers.createPrice,
                                 currencyIdentifier: AccessibilityIdentifiers.createPriceCurrency,
                                 currencySelection: $viewModel.draft.currencyCode)
            }
            OptionalMarker()
        }
    }
}
