import SwiftUI

/// The primary actions under a group's header, decided by `GroupAccess`: members open the chat, invite and create
/// games; outsiders join, sign in first, are told the group is invite-only, or that it is full.
struct GroupActionRow: View {
    let viewModel: GroupDetailViewModel
    let onOpenChat: () -> Void
    let onInvite: () -> Void
    let onCreateEvent: () -> Void
    let onSignIn: () -> Void

    private typealias Copy = AppBranding.Groups

    private var group: SportGroup { viewModel.group }
    private var access: GroupAccess { viewModel.access }

    var body: some View {
        switch access {
        case .member:
            memberActions
        case .canJoin:
            busyButton(Copy.joinGroup) { await viewModel.join() }
                .lilyProminentButton()
                .accessibilityIdentifier(AccessibilityIdentifiers.groupJoin)
        case .guest:
            Button(Copy.joinGroup, action: onSignIn)
                .lilyProminentButton()
                .accessibilityIdentifier(AccessibilityIdentifiers.groupJoin)
        case .inviteOnly:
            Text(Copy.inviteOnly)
                .font(LilyTheme.Fonts.caption)
                .foregroundStyle(.secondary)
        case .full:
            busyButton(Copy.groupFull)
                .lilyProminentButton()
                .accessibilityIdentifier(AccessibilityIdentifiers.groupJoin)
        }
    }

    private var memberActions: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            if viewModel.showsOpenChat {
                Button(action: onOpenChat) {
                    Label(Copy.openChat, systemImage: DesignTokens.Symbols.chat)
                }
                .lilyProminentButton()
                .accessibilityIdentifier(AccessibilityIdentifiers.groupOpenChat)
            }
            HStack(spacing: DesignTokens.Spacing.md) {
                if access.canInvite(in: group) {
                    Button(action: onInvite) {
                        Label(Copy.invite, systemImage: DesignTokens.Symbols.invite)
                    }
                    .lilyGlassButton(labelColor: .lilyInk)
                    .accessibilityIdentifier(AccessibilityIdentifiers.groupInvite)
                }
                if access.canCreateEvents(in: group) {
                    Button(Copy.createGame, action: onCreateEvent)
                        .lilyGlassButton(labelColor: .lilyInk)
                        .accessibilityIdentifier(AccessibilityIdentifiers.groupCreateEvent)
                }
            }
        }
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
