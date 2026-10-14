import SwiftUI

/// The group form in the shared draft sheet; the visibility is chosen on a create and fixed on an edit.
struct GroupDraftSheet<Model: GroupDraftEditing>: View {
    let viewModel: Model
    let title: String
    let submitTitle: String
    let allowsVisibilityChoice: Bool
    let errorCenter: ErrorCenter

    var body: some View {
        DraftSheet(viewModel: viewModel,
                   title: title,
                   submitTitle: submitTitle,
                   cancelIdentifier: AccessibilityIdentifiers.createGroupCancel,
                   submitIdentifier: AccessibilityIdentifiers.createGroupSubmit,
                   errorCenter: errorCenter) { model in
            @Bindable var model = model
            GroupDraftForm(draft: $model.draft, issues: model.issues, allowsVisibilityChoice: allowsVisibilityChoice)
        }
    }
}
