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
            busyButton(Copy.join) { await viewModel.join() }
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
            busyButton(Copy.full)
                .lilyProminentButton()
                .accessibilityIdentifier(AccessibilityIdentifiers.tournamentJoin)
        }
    }

    private func notice(_ text: String) -> some View {
        Text(text)
            .font(LilyTheme.Fonts.caption)
            .foregroundStyle(.secondary)
    }

    /// Action with a spinner beside its title while the request runs. Without an action it is disabled. The caller
    /// applies the button style, which also sets the full width and height (see the Buttons note in CLAUDE.md).
    private func busyButton(_ title: String, action: (() async -> Void)? = nil) -> some View {
        Button {
            Task { await action?() }
        } label: {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Text(title)
                if viewModel.isBusy {
                    ProgressView()
                        .controlSize(.regular)
                        .accessibilityHidden(true)
                }
            }
        }
        .disabled(action == nil || viewModel.isBusy)
    }
}

/// The "more" menu of a tournament, for the organiser and the players: Open chat, and the organiser's Start (while
/// registration is open; disabled under the format's minimum, with the reason as its subtitle), Edit and Cancel;
/// Invite and Report arrive with the next slice.
struct TournamentMenu: View {
    let viewModel: TournamentDetailViewModel
    let onOpenChat: () -> Void
    let onStart: () -> Void
    let onEdit: () -> Void
    let onCancel: () -> Void

    private typealias Copy = AppBranding.Tournaments

    var body: some View {
        Menu {
            if viewModel.canOpenChat {
                Button(AppBranding.Groups.openChat, systemImage: DesignTokens.Symbols.chat, action: onOpenChat)
                    .accessibilityIdentifier(AccessibilityIdentifiers.tournamentOpenChat)
            }
            if viewModel.showsStart {
                Button(action: onStart) {
                    Label(Copy.start, systemImage: DesignTokens.Symbols.play)
                    if let reason = viewModel.startBlockedReason {
                        Text(reason)
                    }
                }
                .disabled(!viewModel.canStart)
                .accessibilityIdentifier(AccessibilityIdentifiers.tournamentStart)
            }
            if viewModel.canEdit {
                Button(AppBranding.Groups.edit, systemImage: DesignTokens.Symbols.edit, action: onEdit)
                    .accessibilityIdentifier(AccessibilityIdentifiers.tournamentEdit)
            }
            if viewModel.canCancel {
                Button(Copy.cancel, systemImage: DesignTokens.Symbols.dismiss, role: .destructive, action: onCancel)
                    .accessibilityIdentifier(AccessibilityIdentifiers.tournamentCancel)
            }
        } label: {
            Label(Copy.tournament, systemImage: DesignTokens.Symbols.more)
        }
        .accessibilityIdentifier(AccessibilityIdentifiers.tournamentMore)
    }
}
