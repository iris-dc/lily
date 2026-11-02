import SwiftUI

/// "Create team": one field for the team's name, judged against the backend's limits, and Create in the bar. Closes as
/// soon as the caller's team exists (`onEntered`: the write's answer or its read-back, before the reminders are
/// offered), or once the entry shows up through a live change.
struct TeamNameSheet: View {
    let viewModel: TournamentDetailViewModel
    let errorCenter: ErrorCenter
    @State private var name = ""
    @FocusState private var isFocused: Bool
    @Environment(\.dismiss) private var dismiss

    private typealias Copy = AppBranding.Tournaments

    private var issue: TeamNameIssue? { TeamNameIssue.issue(in: name) }

    var body: some View {
        NavigationStack {
            ContentScreen {
                Form {
                    Section {
                        TextField(Copy.teamNamePlaceholder, text: $name)
                            .textInputAutocapitalization(.words)
                            .focused($isFocused)
                            .submitLabel(.done)
                            .accessibilityIdentifier(AccessibilityIdentifiers.tournamentTeamName)
                    } footer: {
                        if let issue, !name.isEmpty {
                            Text(Copy.teamNameMessage(for: issue))
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .readableColumn()
            }
            .navigationTitle(Copy.teamNameTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppBranding.Events.Create.cancel, role: .cancel) { dismiss() }
                        .lilyToolbarTextButton()
                        .disabled(viewModel.isBusy)
                }
                ToolbarItem(placement: .confirmationAction) {
                    DraftSubmitButton(title: Copy.createTeam, isSubmitting: viewModel.isBusy, isEnabled: issue == nil) {
                        await viewModel.createTeam(named: name) { dismiss() }
                    }
                    .accessibilityIdentifier(AccessibilityIdentifiers.tournamentTeamSubmit)
                }
            }
            .tint(Color.lilyAccent)
        }
        .presentationDetents([.medium])
        .lilyFormSheet()
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(viewModel.isBusy)
        // A sheet is drawn above the root, so the shared popup mounted there would sit behind this one.
        .errorPopup(errorCenter)
        .onAppear { isFocused = true }
        .onChange(of: viewModel.tournament?.myEntryId) {
            if viewModel.tournament?.hasEntered == true { dismiss() }
        }
    }
}
