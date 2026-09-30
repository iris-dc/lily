import SwiftUI

/// A person in a list (a group's roster, a game's participants): their mark, their name ("You" for the caller) and a
/// trailing badge. Every row but the caller's own opens the person's profile. The identifier is set here, on the link
/// itself: a `.contextMenu` around the row (the roster's) would swallow one applied outside.
struct PersonRow<Badge: View>: View {
    let userID: String
    let displayName: String
    let isSelf: Bool
    let identifier: String
    @ViewBuilder var badge: () -> Badge

    var body: some View {
        if isSelf {
            content
                .accessibilityIdentifier(identifier)
        } else {
            NavigationLink(value: UserProfileDestination(userId: userID, displayName: displayName)) {
                content
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(identifier)
        }
    }

    private var content: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            AvatarCircle(initials: displayName.initials, size: DesignTokens.Layout.avatarMedium)
            Text(AppBranding.People.name(displayName, isSelf: isSelf))
                .font(.body)
                .lineLimit(1)
            Spacer(minLength: DesignTokens.Spacing.sm)
            badge()
                .fixedSize()
        }
        .padding(.vertical, DesignTokens.Spacing.xs)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}
