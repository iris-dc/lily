import SwiftUI

/// One person who may be invited: their mark, their name, what the caller shares with them ("In Kreuzberg Kickers",
/// "Played Sunset 5-a-side") and the Invite button, which spins while the invite is on its way and reads "Invited",
/// disabled, once it went out.
struct InviteCandidateRow: View {
    let candidate: InviteCandidate
    let isSending: Bool
    let onInvite: () -> Void

    private typealias Copy = AppBranding.Groups.Invite
    private typealias Layout = DesignTokens.Layout

    var body: some View {
        ConversationRow(caption: candidate.caption,
                        avatar: AvatarCircle(initials: candidate.displayName.initials, size: Layout.avatarMedium),
                        title: { Text(candidate.displayName) },
                        trailing: { inviteButton })
        // A container first: an identifier on a bare stack is stamped on every element inside it, the button's included.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityIdentifiers.inviteCandidate(candidate.userId))
    }

    private var inviteButton: some View {
        Button(action: onInvite) {
            BusyLabel(candidate.isInvited ? Copy.sent : Copy.send, isBusy: isSending, spinnerSize: .small)
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
