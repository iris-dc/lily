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
        case .member, .conversation, .room:
            memberActions
        case .canJoin:
            BusyButton(Copy.joinGroup, isBusy: viewModel.isBusy) { await viewModel.join() }
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
            BusyButton(Copy.groupFull, isBusy: viewModel.isBusy)
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
}
