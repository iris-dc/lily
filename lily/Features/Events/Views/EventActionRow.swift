import SwiftUI

/// The primary actions under an event's facts, mirroring the group's and the tournament's rows: the host and every
/// participant open the room's chat, and invite while the event has not started. Takes the permissions value, not the
/// view model: the row reads nothing else.
struct EventActionRow: View {
    let permissions: EventPermissions
    let onOpenChat: () -> Void
    let onInvite: () -> Void

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            if permissions.canOpenChat {
                Button(action: onOpenChat) {
                    Label(AppBranding.Groups.openChat, systemImage: DesignTokens.Symbols.chat)
                }
                .lilyProminentButton()
                .accessibilityIdentifier(AccessibilityIdentifiers.eventActionChat)
            }
            if permissions.canInvite {
                Button(action: onInvite) {
                    Label(AppBranding.Groups.invite, systemImage: DesignTokens.Symbols.invite)
                }
                .lilyGlassButton(labelColor: .lilyInk)
                .accessibilityIdentifier(AccessibilityIdentifiers.eventActionInvite)
            }
        }
    }
}
