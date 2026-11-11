import SwiftUI

/// The group form in the shared draft sheet; only the edit uses it since creating walks the wizard.
struct GroupDraftSheet<Model: GroupDraftEditing>: View {
    let viewModel: Model
    let title: String
    let submitTitle: String
    let errorCenter: ErrorCenter

    var body: some View {
        DraftSheet(viewModel: viewModel,
                   title: title,
                   submitTitle: submitTitle,
                   cancelIdentifier: AccessibilityIdentifiers.createGroupCancel,
                   submitIdentifier: AccessibilityIdentifiers.createGroupSubmit,
                   errorCenter: errorCenter) { model in
            @Bindable var model = model
            GroupDraftForm(draft: $model.draft, issues: model.issues)
        }
    }
}
