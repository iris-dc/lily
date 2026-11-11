import SwiftUI

/// The group flow's type step, one idea: which sport the group plays, or any. A search field over the compact type
/// grid (`WizardTypePicker`), led by the "Any type" card; picking fixes the type and auto-advances with the push
/// animation, and re-entering shows the current choice selected. The step owns no issues: a nullable choice is
/// always answered.
struct GroupTypePage<Model: GroupDraftEditing>: View {
    let wizard: any CreationWizardControlling
    @Bindable var viewModel: Model
    let onCancel: () -> Void

    private typealias Copy = AppBranding.Groups.Create
    private static var step: CreationStep { .group(.type) }

    var body: some View {
        WizardStepScaffold(wizard: wizard, step: Self.step, onCancel: onCancel) {
            WizardTypePicker(anyTitle: Copy.anyType,
                             isSelected: { $0 == viewModel.draft.type },
                             pick: pick)
        }
    }

    private func pick(_ type: EventType?) {
        viewModel.draft.type = type
        wizard.advance(from: Self.step)
    }
}
