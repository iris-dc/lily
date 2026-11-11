import SwiftUI

/// The tournament form in the shared draft sheet; only the edit uses it since creating walks the wizard.
struct TournamentDraftSheet<Model: TournamentDraftEditing>: View {
    let viewModel: Model
    let title: String
    let submitTitle: String
    let errorCenter: ErrorCenter

    var body: some View {
        DraftSheet(viewModel: viewModel,
                   title: title,
                   submitTitle: submitTitle,
                   cancelIdentifier: AccessibilityIdentifiers.tournamentFormCancel,
                   submitIdentifier: AccessibilityIdentifiers.tournamentSubmit,
                   errorCenter: errorCenter) { TournamentDraftForm(viewModel: $0) }
    }
}

/// The organiser's tournament in the form: Cancel and Save in the bar. (Creating walks the wizard since slice 3 of
/// the creation-wizard plan; this form stays for the edit.)
struct EditTournamentSheet: View {
    let viewModel: EditTournamentViewModel
    let errorCenter: ErrorCenter

    var body: some View {
        TournamentDraftSheet(viewModel: viewModel,
                             title: AppBranding.Tournaments.Create.editTitle,
                             submitTitle: AppBranding.Tournaments.Create.save,
                             errorCenter: errorCenter)
    }
}

#Preview {
    let dependencies = AppDependencies.makeMock()
    EditTournamentSheet(viewModel: dependencies.makeEditTournamentViewModel(
                            for: MockTournamentFixtures.make(now: .now)[0].tournament) { _ in },
                        errorCenter: dependencies.errorCenter)
}
