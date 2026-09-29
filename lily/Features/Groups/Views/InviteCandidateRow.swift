import SwiftUI

/// One person who may be invited: their mark, their name, what the caller shares with them ("In Kreuzberg Kickers",
/// "Played Sunset 5-a-side") and the Invite button, which spins while the invite is on its way and reads "Invited",
/// disabled, once it went out.
struct InviteCandidateRow: View {
    let candidate: InviteCandidate
    let isSending: Bool
    let onInvite: () -> Void

    private typealias Copy = AppBranding.Groups.Invite

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            AvatarCircle(initials: candidate.displayName.initials, size: DesignTokens.Layout.avatarMedium)
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(candidate.displayName)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                Text(candidate.caption)
                    .font(LilyTheme.Fonts.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: DesignTokens.Spacing.sm)
            inviteButton
        }
        .padding(.vertical, DesignTokens.Spacing.md)
        // A container first: an identifier on a bare stack is stamped on every element inside it, the button's included.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityIdentifiers.inviteCandidate(candidate.userId))
    }

    private var inviteButton: some View {
        Button(action: onInvite) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Text(candidate.isInvited ? Copy.sent : Copy.send)
                if isSending {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityHidden(true)
                }
            }
        }
        .lilyGlassButton(sizing: .fitted, controlSize: .regular, labelColor: .lilyInk)
        .disabled(candidate.isInvited || isSending)
        .accessibilityIdentifier(AccessibilityIdentifiers.inviteSend(candidate.userId))
    }
}

#Preview {
    ContentScreen {
        VStack(spacing: 0) {
            InviteCandidateRow(candidate: InviteCandidate(userId: "u-1",
                                                          displayName: "Marta",
                                                          via: .group,
                                                          viaName: "Kreuzberg Kickers"),
                               isSending: false) {}
            InviteCandidateRow(candidate: InviteCandidate(userId: "u-2",
                                                          displayName: "Priya",
                                                          via: .event,
                                                          viaName: "Sunrise yoga",
                                                          isInvited: true),
                               isSending: false) {}
        }
        .padding()
    }
}
