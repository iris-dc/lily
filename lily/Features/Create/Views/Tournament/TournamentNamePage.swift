import SwiftUI

/// The tournament flow's first step, one idea: what the tournament is called. The keyboard is up on entry so typing
/// starts at once; the field and its identifier are the tournament form's.
struct TournamentNamePage<Model: TournamentDraftEditing>: View {
    let wizard: any CreationWizardControlling
    @Bindable var viewModel: Model
    let onCancel: () -> Void
    @FocusState private var focusedField: Field?

    enum Field: Hashable { case name }

    private typealias Copy = AppBranding.Tournaments.Create
    private static var step: CreationStep { .tournament(.name) }

    var body: some View {
        WizardStepScaffold(wizard: wizard,
                           step: Self.step,
                           scrollTarget: focusedField.map { AnyHashable($0) },
                           onCancel: onCancel) {
            nameField
            WizardIssueHint(message: wizard.blockingMessage(on: Self.step))
        }
        // Focus drops the moment the stack moves (a write from a view already leaving the hierarchy is ignored),
        // so a pop-return never re-presents the keyboard over the bottom bar.
        .onChange(of: wizard.path) { focusedField = nil }
        .onAppear { focusedField = .name }
    }

    private var nameField: some View {
        TextField(Copy.nameField, text: $viewModel.draft.name, prompt: Text(Copy.namePlaceholder))
            .textInputAutocapitalization(.words)
            .focused($focusedField, equals: .name)
            .submitLabel(.done)
            .accessibilityIdentifier(AccessibilityIdentifiers.tournamentName)
            .lilyField()
            .id(Field.name)
    }
}
