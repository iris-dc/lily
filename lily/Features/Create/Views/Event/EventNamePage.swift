import SwiftUI

/// The event flow's first step, one idea: what the event is called. The keyboard is up on entry so typing starts at
/// once; the field and its identifier are the create form's.
struct EventNamePage<Model: EventDraftEditing>: View {
    let wizard: any CreationWizardControlling
    @Bindable var viewModel: Model
    let onCancel: () -> Void
    @FocusState private var focusedField: Field?

    enum Field: Hashable { case title }

    private typealias Copy = AppBranding.Events.Create
    private static var step: CreationStep { .event(.name) }

    var body: some View {
        WizardStepScaffold(wizard: wizard,
                           step: Self.step,
                           scrollTarget: focusedField.map { AnyHashable($0) },
                           onCancel: onCancel) {
            titleField
            WizardIssueHint(message: wizard.blockingMessage(on: Self.step))
        }
        // Focus drops the moment the stack moves (a write from a view already leaving the hierarchy is ignored),
        // so a pop-return never re-presents the keyboard over the bottom bar.
        .onChange(of: wizard.path) { focusedField = nil }
        .onAppear { focusedField = .title }
    }

    private var titleField: some View {
        TextField(Copy.titleField, text: $viewModel.draft.title, prompt: Text(Copy.titlePlaceholder))
            .textInputAutocapitalization(.sentences)
            .focused($focusedField, equals: .title)
            .submitLabel(.done)
            .accessibilityIdentifier(AccessibilityIdentifiers.createTitle)
            .lilyField()
            .id(Field.title)
    }
}
