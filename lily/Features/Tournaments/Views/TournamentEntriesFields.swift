import SwiftUI

/// Team size (fixed once created), the entries cap (fixed after the start) and whether a match may end level.
struct TournamentEntriesFields<Model: TournamentDraftEditing>: View {
    @Bindable var viewModel: Model

    private typealias Copy = AppBranding.Tournaments.Create

    var body: some View {
        if viewModel.allowsStructureChanges {
            Stepper(value: $viewModel.draft.teamSize, in: AppConfig.Tournaments.teamSizeRange) {
                Text(Copy.teamSize(viewModel.draft.teamSize))
            }
            .accessibilityIdentifier(AccessibilityIdentifiers.tournamentTeamSize)
        }
        Stepper(value: $viewModel.draft.maxEntries, in: viewModel.entriesRange) {
            Text(Copy.maxEntries(viewModel.draft.maxEntries, teamSize: viewModel.draft.teamSize))
        }
        .disabled(viewModel.isLocked)
        .accessibilityIdentifier(AccessibilityIdentifiers.tournamentMaxEntries)
        CaptionedControl(Copy.draws) {
            Picker(Copy.draws, selection: allowsDraws) {
                Text(Copy.drawsAllowed).tag(true)
                Text(Copy.drawsNotAllowed).tag(false)
            }
            .pickerStyle(.segmented)
            .disabled(viewModel.isLocked)
            .accessibilityIdentifier(AccessibilityIdentifiers.tournamentDraws)
        }
    }

    /// The draft follows the type's default until the organiser picks; the picker shows the resolved choice.
    private var allowsDraws: Binding<Bool> {
        Binding(get: { viewModel.draft.resolvedAllowsDraws }, set: { viewModel.draft.allowsDraws = $0 })
    }
}
