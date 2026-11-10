import SwiftUI

/// Which group hosts the tournament (its visibility then follows the group's), or who can join a standalone one.
/// Both controls are shared: the group row with the event form, the visibility picker with the group form.
struct TournamentWhoMayJoinControls<Model: TournamentDraftEditing>: View {
    @Bindable var viewModel: Model

    private typealias Copy = AppBranding.Tournaments.Create

    var body: some View {
        if viewModel.showsGroupRow {
            HostingGroupRow(lockedGroup: viewModel.lockedGroup,
                            showsNoEligibleGroups: viewModel.explainsNoEligibleGroups,
                            eligibleGroups: viewModel.eligibleGroups,
                            selection: $viewModel.draft.group)
        }
        if viewModel.allowsStructureChanges, viewModel.draft.group == nil {
            GroupVisibilityChoice(visibility: $viewModel.draft.visibility,
                                  title: Copy.visibility,
                                  identifier: AccessibilityIdentifiers.tournamentVisibility)
        }
    }
}
