import SwiftUI

/// The tournament flow's type step, one idea: which sport is played, fixed once created. Glass choice cards like the
/// kind page; picking fixes the type and auto-advances, and re-entering shows the current choice selected. The step
/// owns no issues: one type is always selected.
struct TournamentTypePage<Model: TournamentDraftEditing>: View {
    let wizard: any CreationWizardControlling
    @Bindable var viewModel: Model
    let onCancel: () -> Void

    private static var step: CreationStep { .tournament(.type) }

    var body: some View {
        WizardStepScaffold(wizard: wizard, step: Self.step, onCancel: onCancel) {
            ForEach(EventType.known, id: \.self) { type in
                WizardChoiceCard(title: type.displayName,
                                 systemImage: type.symbolName,
                                 isSelected: type == viewModel.draft.type,
                                 identifier: AccessibilityIdentifiers.createEventType(type.wireName)) {
                    pick(type)
                }
            }
        }
    }

    private func pick(_ type: EventType) {
        viewModel.draft.type = type
        wizard.advance(from: Self.step)
    }
}
