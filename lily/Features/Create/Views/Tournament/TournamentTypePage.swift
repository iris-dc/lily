import SwiftUI

/// The tournament flow's type step, one idea: which sport is played, fixed once created. A search field over the
/// compact type grid (`WizardTypePicker`); picking fixes the type and auto-advances, and re-entering shows the
/// current choice selected. The step owns no issues: one type is always selected.
struct TournamentTypePage<Model: TournamentDraftEditing>: View {
    let wizard: any CreationWizardControlling
    @Bindable var viewModel: Model
    let onCancel: () -> Void

    private static var step: CreationStep { .tournament(.type) }

    var body: some View {
        WizardStepScaffold(wizard: wizard, step: Self.step, onCancel: onCancel) {
            WizardTypePicker(isSelected: { $0 == viewModel.draft.type }, pick: pick)
        }
    }

    /// `nil` never arrives: the picker offers no "Any" entry here.
    private func pick(_ type: EventType?) {
        guard let type else { return }
        viewModel.draft.type = type
        wizard.advance(from: Self.step)
    }
}
