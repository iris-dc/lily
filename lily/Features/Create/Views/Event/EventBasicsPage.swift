import SwiftUI

/// The event flow's first step: the title in the glass capsule field, the type chips, when the game starts and the
/// hosting-group row, with the step's first live issue under them. The fields and their identifiers are the create
/// form's, rendered in the wizard's glass substrate.
struct EventBasicsPage<Model: EventDraftEditing>: View {
    let wizard: CreationWizardModel<Model>
    @Bindable var viewModel: Model
    let onCancel: () -> Void
    @FocusState private var focusedField: Field?

    enum Field: Hashable { case title }

    private typealias Copy = AppBranding.Events.Create
    private static var step: CreationStep { .event(.basics) }

    var body: some View {
        WizardStepScaffold(wizard: wizard,
                           step: Self.step,
                           scrollTarget: focusedField.map { AnyHashable($0) },
                           onCancel: onCancel) {
            titleField
            typeChips
            whenCard
            if viewModel.showsGroupRow { groupCard }
            WizardIssueHint(issue: wizard.firstBlockingIssue(on: Self.step))
        }
        // Focus drops the moment the stack moves (a write from a view already leaving the hierarchy is ignored),
        // so a pop-return never re-presents the keyboard over the bottom bar.
        .onChange(of: wizard.path) { focusedField = nil }
    }

    private var titleField: some View {
        TextField(Copy.titleField, text: $viewModel.draft.title, prompt: Text(Copy.titlePlaceholder))
            .textInputAutocapitalization(.sentences)
            .focused($focusedField, equals: .title)
            .submitLabel(.done)
            .accessibilityIdentifier(AccessibilityIdentifiers.createTitle)
            .lilyField()
            .id(Field.title)
    }

    /// Single choice in the shared chip look; one type is always selected.
    private var typeChips: some View {
        CaptionedControl(Copy.eventType) {
            EventTypeChips(isSelected: { $0 == viewModel.draft.type }, onSelect: { type in
                if let type { viewModel.draft.type = type }
            })
        }
    }

    private var whenCard: some View {
        GlassCard {
            DatePicker(Copy.startsAt, selection: $viewModel.draft.startsAt, in: viewModel.earliestStart...)
        }
    }

    /// The shared group row behind an outer label, since a menu picker outside a `Form` draws no label of its own;
    /// `labelsHidden()` keeps the row's own one quiet in every shape.
    private var groupCard: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            GlassCard {
                HStack(spacing: DesignTokens.Spacing.md) {
                    Text(Copy.group)
                    Spacer()
                    HostingGroupRow(lockedGroup: viewModel.lockedGroup,
                                    showsNoEligibleGroups: viewModel.explainsNoEligibleGroups,
                                    eligibleGroups: viewModel.eligibleGroups,
                                    selection: $viewModel.draft.group)
                        .labelsHidden()
                }
            }
            if viewModel.explainsNoEligibleGroups {
                Text(Copy.noEligibleGroups)
                    .font(LilyTheme.Fonts.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
