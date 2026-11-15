import SwiftUI

/// The primary actions under a tournament's facts, mirroring a group's `GroupActionRow`: an involved caller (the
/// organiser or an entrant) opens the room's chat, and invites while registration is open. The toolbar menu keeps the
/// same items, as the group detail's menu does beside its row.
struct TournamentActionRow: View {
    let viewModel: TournamentDetailViewModel
    let onOpenChat: () -> Void
    let onInvite: () -> Void

    var body: some View {
        let permissions = viewModel.permissions
        VStack(spacing: DesignTokens.Spacing.md) {
            if permissions.canOpenChat {
                Button(action: onOpenChat) {
                    Label(AppBranding.Groups.openChat, systemImage: DesignTokens.Symbols.chat)
                }
                .lilyProminentButton()
                .accessibilityIdentifier(AccessibilityIdentifiers.tournamentActionChat)
            }
            if permissions.canInvite {
                Button(action: onInvite) {
                    Label(AppBranding.Groups.invite, systemImage: DesignTokens.Symbols.invite)
                }
                .lilyGlassButton(labelColor: .lilyInk)
                .accessibilityIdentifier(AccessibilityIdentifiers.tournamentActionInvite)
            }
        }
    }
}
