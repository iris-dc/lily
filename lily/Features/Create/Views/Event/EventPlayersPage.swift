import SwiftUI

/// The event flow's final step: the player limit with its stepper, the optional description and looking-for notes in
/// glass fields, and the level and price in one card. The scaffold's bottom bar carries the submit button here; the
/// step's first live issue reads under the fields.
struct EventPlayersPage<Model: EventDraftEditing>: View {
    let wizard: CreationWizardModel<Model>
    @Bindable var viewModel: Model
    let onCancel: () -> Void
    @FocusState private var focusedField: Field?

    enum Field: Hashable { case description, lookingFor }

    private typealias Copy = AppBranding.Events.Create
    private static var step: CreationStep { .event(.players) }

    var body: some View {
        WizardStepScaffold(wizard: wizard,
                           step: Self.step,
                           scrollTarget: focusedField.map { AnyHashable($0) },
                           onCancel: onCancel) {
            playersCard
            descriptionField
            lookingForField
            levelAndPriceCard
            WizardIssueHint(issue: wizard.firstBlockingIssue(on: Self.step))
        }
        // Focus drops the moment the stack moves (a write from a view already leaving the hierarchy is ignored),
        // so a pop-return never re-presents the keyboard over the bottom bar.
        .onChange(of: wizard.path) { focusedField = nil }
    }

    private var playersCard: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            GlassCard {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    EventPlayersFields(viewModel: viewModel)
                }
            }
            if let hint = Copy.hint(for: viewModel.draft.playerLimit) {
                Text(hint)
                    .font(LilyTheme.Fonts.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var descriptionField: some View {
        TextField(Copy.descriptionPlaceholder, text: $viewModel.draft.description, axis: .vertical)
            .textInputAutocapitalization(.sentences)
            .lineLimit(DesignTokens.Layout.multilineFieldLines)
            .focused($focusedField, equals: .description)
            .lilyMultilineField()
            .id(Field.description)
    }

    private var lookingForField: some View {
        TextField(Copy.lookingForPlaceholder, text: $viewModel.draft.lookingFor)
            .textInputAutocapitalization(.sentences)
            .focused($focusedField, equals: .lookingFor)
            .lilyField()
            .id(Field.lookingFor)
    }

    /// The level behind an outer label, since a menu picker outside a `Form` draws no label of its own; the price in
    /// the shared trailing field, empty or zero meaning free.
    private var levelAndPriceCard: some View {
        GlassCard {
            VStack(spacing: DesignTokens.Spacing.md) {
                HStack(spacing: DesignTokens.Spacing.md) {
                    Text(AppBranding.Events.levelLabel)
                    Spacer()
                    SkillLevelPicker(selection: $viewModel.draft.skillLevel)
                        .lilyMenuPicker()
                        .labelsHidden()
                }
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
    }
}
