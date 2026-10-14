import SwiftUI

/// The primary control under a tournament's detail, decided by `TournamentParticipation`: Join, Create team, Leave,
/// or a line saying why there is nothing to do; above it the organiser's notice when the caller runs the tournament.
struct TournamentParticipationControl: View {
    let viewModel: TournamentDetailViewModel
    let onCreateTeam: () -> Void
    let onLeave: () -> Void

    private typealias Copy = AppBranding.Tournaments

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            if viewModel.role.isOrganizer {
                notice(Copy.organizingNotice)
            }
            control
        }
    }

    @ViewBuilder private var control: some View {
        switch viewModel.participation {
        case .hidden:
            EmptyView()
        case .join:
            BusyButton(Copy.join, isBusy: viewModel.isBusy) { await viewModel.join() }
                .lilyProminentButton()
                .accessibilityIdentifier(AccessibilityIdentifiers.tournamentJoin)
        case .createTeam:
            Button(Copy.createTeam, action: onCreateTeam)
                .lilyProminentButton()
                .disabled(viewModel.isBusy)
                .accessibilityIdentifier(AccessibilityIdentifiers.tournamentCreateTeam)
        case .leave:
            Button(Copy.leave, action: onLeave)
                .lilyGlassButton()
                .disabled(viewModel.isBusy)
                .accessibilityIdentifier(AccessibilityIdentifiers.tournamentLeave)
        case .entered:
            notice(Copy.enteredNotice)
        case .registrationClosed:
            notice(Copy.registrationClosed)
        case .full:
            BusyButton(Copy.full, isBusy: viewModel.isBusy)
                .lilyProminentButton()
                .accessibilityIdentifier(AccessibilityIdentifiers.tournamentJoin)
        }
    }

    private func notice(_ text: String) -> some View {
        Text(text)
            .font(LilyTheme.Fonts.caption)
            .foregroundStyle(.secondary)
    }
}

/// The "more" menu of a tournament, for the organiser, the players and anyone signed in: Open chat and Invite (entrants
/// and the organiser, while registration is open), the organiser's Start (while registration is open; disabled under
/// the format's minimum, with the reason as its subtitle), Edit and Cancel, and Report tournament for everyone else.
struct TournamentMenu: View {
    let viewModel: TournamentDetailViewModel
    let onOpenChat: () -> Void
    let onInvite: () -> Void
    let onStart: () -> Void
    let onEdit: () -> Void
    let onCancel: () -> Void
    let onReport: () -> Void

    private typealias Copy = AppBranding.Tournaments

    var body: some View {
        let permissions = viewModel.permissions
        Menu {
            if permissions.canOpenChat {
                Button(AppBranding.Groups.openChat, systemImage: DesignTokens.Symbols.chat, action: onOpenChat)
                    .accessibilityIdentifier(AccessibilityIdentifiers.tournamentOpenChat)
            }
            if permissions.canInvite {
                Button(AppBranding.Groups.invite, systemImage: DesignTokens.Symbols.invite, action: onInvite)
                    .accessibilityIdentifier(AccessibilityIdentifiers.tournamentInvite)
            }
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
