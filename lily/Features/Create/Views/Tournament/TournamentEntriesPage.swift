import SwiftUI

/// The tournament flow's entries step, one idea: who enters — the team size, the entry cap and whether a match may
/// end level, the tournament form's controls in one glass card with the caption explaining the rules. Owns the three
/// entries issues.
struct TournamentEntriesPage<Model: TournamentDraftEditing>: View {
    let wizard: any CreationWizardControlling
    @Bindable var viewModel: Model
    let onCancel: () -> Void

    private static var step: CreationStep { .tournament(.entries) }

    var body: some View {
        WizardStepScaffold(wizard: wizard, step: Self.step, onCancel: onCancel) {
            GlassCard {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    TournamentEntriesFields(viewModel: viewModel)
                }
            }
            WizardIssueHint(message: wizard.blockingMessage(on: Self.step))
        }
    }
}
