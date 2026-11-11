import SwiftUI

/// The event flow's type step, one idea: what kind of game it is. A search field over the compact type grid
/// (`WizardTypePicker`); picking fixes the type and auto-advances with the push animation, and re-entering shows the
/// current choice selected (the same card advances again). The step owns no issues: one type is always selected.
struct EventTypePage<Model: EventDraftEditing>: View {
    let wizard: any CreationWizardControlling
    @Bindable var viewModel: Model
    let onCancel: () -> Void

    private static var step: CreationStep { .event(.type) }

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
