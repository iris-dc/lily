import SwiftUI

/// The tournament flow's schedule step, one idea: when it runs — the start, and the registration deadline the
/// caption explains. The controls are the tournament form's; the step owns the two schedule issues.
struct TournamentSchedulePage<Model: TournamentDraftEditing>: View {
    let wizard: any CreationWizardControlling
    @Bindable var viewModel: Model
    let onCancel: () -> Void

    private static var step: CreationStep { .tournament(.schedule) }

    var body: some View {
        WizardStepScaffold(wizard: wizard, step: Self.step, onCancel: onCancel) {
            GlassCard {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    TournamentScheduleFields(viewModel: viewModel)
                }
            }
            WizardIssueHint(message: wizard.blockingMessage(on: Self.step))
        }
    }
}
