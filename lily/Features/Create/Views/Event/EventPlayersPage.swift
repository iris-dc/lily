import SwiftUI

/// The event flow's players step, one idea: how many play, and at what level. The limit keeps the create form's
/// segmented control and stepper with the per-limit explanation under them; the step owns the capacity issues.
struct EventPlayersPage<Model: EventDraftEditing>: View {
    let wizard: CreationWizardModel<Model>
    @Bindable var viewModel: Model
    let onCancel: () -> Void

    private typealias Copy = AppBranding.Events.Create
    private static var step: CreationStep { .event(.players) }

    var body: some View {
        WizardStepScaffold(wizard: wizard, step: Self.step, onCancel: onCancel) {
            playersCard
            levelCard
            WizardIssueHint(issue: wizard.firstBlockingIssue(on: Self.step))
        }
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

    /// The level behind an outer label, since a menu picker outside a `Form` draws no label of its own.
    private var levelCard: some View {
        GlassCard {
            HStack(spacing: DesignTokens.Spacing.md) {
                Text(AppBranding.Events.levelLabel)
                Spacer()
                SkillLevelPicker(selection: $viewModel.draft.skillLevel)
                    .lilyMenuPicker()
                    .labelsHidden()
            }
        }
    }
}
