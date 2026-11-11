import SwiftUI

/// The group flow's description step, one idea: what the group is about, optional (the caption says so for whom it
/// is written). Owns the too-long issue.
struct GroupDescriptionPage<Model: GroupDraftEditing>: View {
    let wizard: any CreationWizardControlling
    @Bindable var viewModel: Model
    let onCancel: () -> Void
    @FocusState private var focusedField: Field?

    enum Field: Hashable { case description }

    private typealias Copy = AppBranding.Groups.Create
    private static var step: CreationStep { .group(.description) }

    var body: some View {
        WizardStepScaffold(wizard: wizard,
                           step: Self.step,
                           scrollTarget: focusedField.map { AnyHashable($0) },
                           onCancel: onCancel) {
            descriptionField
            WizardIssueHint(message: wizard.blockingMessage(on: Self.step))
        }
        // Focus drops the moment the stack moves (a write from a view already leaving the hierarchy is ignored),
        // so a pop-return never re-presents the keyboard over the bottom bar.
        .onChange(of: wizard.path) { focusedField = nil }
    }

    private var descriptionField: some View {
        TextField(Copy.descriptionPlaceholder, text: $viewModel.draft.description, axis: .vertical)
            .textInputAutocapitalization(.sentences)
            .lineLimit(DesignTokens.Layout.multilineFieldLines)
            .focused($focusedField, equals: .description)
            .accessibilityIdentifier(AccessibilityIdentifiers.createGroupDescription)
            .lilyMultilineField()
            .id(Field.description)
    }
}
