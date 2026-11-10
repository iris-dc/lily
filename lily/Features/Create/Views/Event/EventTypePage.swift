import SwiftUI

/// The event flow's type step, one idea: what kind of game it is. Glass choice cards like the kind page; picking
/// fixes the type and auto-advances with the push animation, and re-entering shows the current choice selected (the
/// same card advances again). The step owns no issues: one type is always selected.
struct EventTypePage<Model: EventDraftEditing>: View {
    let wizard: CreationWizardModel<Model>
    @Bindable var viewModel: Model
    let onCancel: () -> Void

    private static var step: CreationStep { .event(.type) }

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
