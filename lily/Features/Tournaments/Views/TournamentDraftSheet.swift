import SwiftUI

/// The tournament form in the shared draft sheet.
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

/// The create form in a sheet: Cancel and Create in the bar. Closes itself once the backend answered.
struct CreateTournamentSheet: View {
    let viewModel: CreateTournamentViewModel
    let errorCenter: ErrorCenter

    var body: some View {
        TournamentDraftSheet(viewModel: viewModel,
                             title: AppBranding.Tournaments.Create.title,
                             submitTitle: AppBranding.Tournaments.Create.submit,
                             errorCenter: errorCenter)
    }
}

/// The organiser's tournament in the form: Cancel and Save in the bar.
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
    CreateTournamentSheet(viewModel: dependencies.makeCreateTournamentViewModel { _ in }, errorCenter: dependencies.errorCenter)
}
