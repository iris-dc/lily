import SwiftUI

/// The event flow's final step, all of it optional: the price, what to expect and who the host is looking for. The
/// scaffold's bottom bar carries the create button here; the step's first live issue reads under the fields.
struct EventDetailsPage<Model: EventDraftEditing>: View {
    let wizard: any CreationWizardControlling
    @Bindable var viewModel: Model
    let onCancel: () -> Void
    @FocusState private var focusedField: Field?

    enum Field: Hashable { case description, lookingFor }

    private typealias Copy = AppBranding.Events.Create
    private static var step: CreationStep { .event(.details) }

    var body: some View {
        WizardStepScaffold(wizard: wizard,
                           step: Self.step,
                           scrollTarget: focusedField.map { AnyHashable($0) },
                           onCancel: onCancel) {
            priceCard
            descriptionField
            lookingForField
            WizardIssueHint(message: wizard.blockingMessage(on: Self.step))
        }
        // Focus drops the moment the stack moves (a write from a view already leaving the hierarchy is ignored),
        // so a pop-return never re-presents the keyboard over the bottom bar.
        .onChange(of: wizard.path) { focusedField = nil }
    }

    /// The price in the shared trailing field, empty or zero meaning free; the symbol is the inline currency menu,
    /// seeded with the user's settings currency and written straight into the draft (the event keeps its own).
    /// The shared marker sits below the card, like below every optional control, never inside it.
    private var priceCard: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            GlassCard {
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
            }
            OptionalMarker()
        }
    }

    private var descriptionField: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            TextField(Copy.descriptionPlaceholder, text: $viewModel.draft.description, axis: .vertical)
                .textInputAutocapitalization(.sentences)
                .lineLimit(DesignTokens.Layout.multilineFieldLines)
                .focused($focusedField, equals: .description)
                .lilyMultilineField()
                .id(Field.description)
            OptionalMarker()
        }
    }

    private var lookingForField: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            TextField(Copy.lookingForPlaceholder, text: $viewModel.draft.lookingFor)
                .textInputAutocapitalization(.sentences)
                .focused($focusedField, equals: .lookingFor)
                .lilyField()
                .id(Field.lookingFor)
            OptionalMarker()
        }
    }
}
