import SwiftUI

/// The tournament flow's format step, one idea: how the matches are drawn — a knockout bracket, or everyone against
/// everyone — fixed once created. Picking writes through `select(format:)`, which pulls the entries under the new
/// cap, and auto-advances. The step owns no issues: one format is always selected.
struct TournamentFormatPage<Model: TournamentDraftEditing>: View {
    let wizard: any CreationWizardControlling
    @Bindable var viewModel: Model
    let onCancel: () -> Void

    private static var step: CreationStep { .tournament(.format) }

    var body: some View {
        WizardStepScaffold(wizard: wizard, step: Self.step, onCancel: onCancel) {
            ForEach(TournamentFormat.known, id: \.self) { format in
                WizardChoiceCard(title: format.displayName,
                                 systemImage: format.drawsBracket ? DesignTokens.Symbols.bracket
                                                                  : DesignTokens.Symbols.standings,
                                 isSelected: format == viewModel.draft.format,
                                 identifier: AccessibilityIdentifiers.createFormat(format.wireName)) {
                    pick(format)
                }
            }
        }
    }

    private func pick(_ format: TournamentFormat) {
        viewModel.draft.select(format: format)
        wizard.advance(from: Self.step)
    }
}
