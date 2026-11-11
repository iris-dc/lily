import SwiftUI

/// The group flow's type step, one idea: which sport the group plays, or any. Glass choice cards like the kind page;
/// picking fixes the type and auto-advances with the push animation, and re-entering shows the current choice
/// selected. The step owns no issues: a nullable choice is always answered.
struct GroupTypePage<Model: GroupDraftEditing>: View {
    let wizard: any CreationWizardControlling
    @Bindable var viewModel: Model
    let onCancel: () -> Void

    private typealias Copy = AppBranding.Groups.Create
    private static var step: CreationStep { .group(.type) }

    var body: some View {
        WizardStepScaffold(wizard: wizard, step: Self.step, onCancel: onCancel) {
            WizardChoiceCard(title: Copy.anyType,
                             systemImage: DesignTokens.Symbols.anyType,
                             isSelected: viewModel.draft.type == nil,
                             identifier: AccessibilityIdentifiers.createTypeAny) {
                pick(nil)
            }
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

    private func pick(_ type: EventType?) {
        viewModel.draft.type = type
        wizard.advance(from: Self.step)
    }
}
