import SwiftUI

/// The tournament flow's final step: the optional description (the caption says so); the scaffold's bottom bar
/// carries the create button here, gated by the whole-draft rule. Owns the too-long issue.
struct TournamentDetailsPage<Model: TournamentDraftEditing>: View {
    let wizard: any CreationWizardControlling
    @Bindable var viewModel: Model
    let onCancel: () -> Void
    @FocusState private var focusedField: Field?

    enum Field: Hashable { case description }

    private typealias Copy = AppBranding.Tournaments.Create
    private static var step: CreationStep { .tournament(.details) }

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
            .lilyMultilineField()
            .id(Field.description)
    }
}
