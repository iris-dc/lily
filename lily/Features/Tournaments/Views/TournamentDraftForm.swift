import SwiftUI

/// Every field of a tournament, new or the organiser's own, grouped the way an organiser thinks: the tournament, where,
/// when, the entries, who can join, and the optional description. Under each group the first thing still wrong with it.
/// Segmented pickers throughout, never a toggle. Section contents are standalone `Tournament*Controls`/`*Fields`
/// views the sections recompose. The Where, When and Who sections are in the `+Schedule` file. Where
/// follows the first section as on the event form: a `Form` instantiates rows only near the viewport, and the UI tests
/// (and a user with the keyboard up) reach the place field without a scroll this way.
struct TournamentDraftForm<Model: TournamentDraftEditing>: View {
    @Bindable var viewModel: Model
    @FocusState var focusedField: Field?

    enum Field { case name, locationName }

    typealias Copy = AppBranding.Tournaments.Create

    var body: some View {
        Form {
            tournamentSection
            whereSection
            whenSection
            entriesSection
            if viewModel.showsGroupRow || viewModel.allowsStructureChanges {
                whoSection
            }
            detailsSection
        }
        .scrollContentBackground(.hidden)
        .readableColumn()
        .tint(Color.lilyAccent)
    }

    private var tournamentSection: some View {
        Section {
            TextField(Copy.nameField, text: $viewModel.draft.name, prompt: Text(Copy.namePlaceholder))
                .textInputAutocapitalization(.words)
                .focused($focusedField, equals: .name)
                .submitLabel(.next)
                .onSubmit { focusedField = .locationName }
                .accessibilityIdentifier(AccessibilityIdentifiers.tournamentName)
            if viewModel.allowsStructureChanges {
                TournamentBasicsControls(viewModel: viewModel)
            }
        } header: {
            Text(Copy.tournamentSection)
        } footer: {
            viewModel.issue(for: .nameTooShort, .nameTooLong)
                .map { Text(Copy.message(for: $0, format: viewModel.draft.format)) }
        }
    }

    /// Team size (fixed once created), the entries cap (fixed after the start) and whether a match may end level.
    private var entriesSection: some View {
        Section {
            TournamentEntriesFields(viewModel: viewModel)
        } header: {
            Text(Copy.entries)
        } footer: {
            viewModel.issue(for: .teamSizeOutOfRange, .maxEntriesOutOfRange, .maxEntriesBelowEntries)
                .map { Text(Copy.message(for: $0, format: viewModel.draft.format)) }
        }
    }
}

#Preview {
    let dependencies = AppDependencies.makeMock()
    NavigationStack {
        ContentScreen {
            TournamentDraftForm(viewModel: dependencies.makeCreateTournamentViewModel { _ in })
        }
    }
}
