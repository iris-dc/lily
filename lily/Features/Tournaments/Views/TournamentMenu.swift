import SwiftUI

/// The "more" menu of a tournament: the organiser's Start (while registration is open; disabled under the format's
/// minimum, with the reason as its subtitle), Edit and Cancel, and Report tournament for everyone else. Chat and
/// invite live in the detail's pinned bar.
struct TournamentMenu: View {
    let viewModel: TournamentDetailViewModel
    let onStart: () -> Void
    let onEdit: () -> Void
    let onCancel: () -> Void
    let onReport: () -> Void

    private typealias Copy = AppBranding.Tournaments

    var body: some View {
        let permissions = viewModel.permissions
        Menu {
            if permissions.showsStart {
                Button(action: onStart) {
                    Label(Copy.start, systemImage: DesignTokens.Symbols.play)
                    if let reason = permissions.startBlockedReason {
                        Text(reason)
                    }
                }
                .disabled(!permissions.canStart)
                .accessibilityIdentifier(AccessibilityIdentifiers.tournamentStart)
            }
            if permissions.canEdit {
                Button(AppBranding.Groups.edit, systemImage: DesignTokens.Symbols.edit, action: onEdit)
                    .accessibilityIdentifier(AccessibilityIdentifiers.tournamentEdit)
            }
            if permissions.canCancel {
                Button(Copy.cancel, systemImage: DesignTokens.Symbols.dismiss, role: .destructive, action: onCancel)
                    .accessibilityIdentifier(AccessibilityIdentifiers.tournamentCancel)
            }
            if permissions.canReport {
                Button(Copy.report, systemImage: DesignTokens.Symbols.report, action: onReport)
                    .accessibilityIdentifier(AccessibilityIdentifiers.tournamentReport)
            }
        } label: {
            Label(Copy.tournament, systemImage: DesignTokens.Symbols.more)
        }
        .accessibilityIdentifier(AccessibilityIdentifiers.tournamentMore)
    }
}
