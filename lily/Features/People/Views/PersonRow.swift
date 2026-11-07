import SwiftUI

/// A person in a list (a group's roster, a game's participants): their mark, their name ("You" for the caller) and a
/// trailing badge. Every row but the caller's own opens the person's profile; a deleted account (`deleted`, the wire's
/// tombstone flag) shows the fixed glyph and the localized name and opens nothing (`Tombstone`). The identifier is set
/// here, on the link itself: a `.contextMenu` around the row (the roster's) would swallow one applied outside.
struct PersonRow<Badge: View>: View {
    let userID: String
    let displayName: String
    let isSelf: Bool
    let identifier: String
    /// The person's account was deleted; absent (the rosters carry no flag) reads as not deleted.
    var deleted: Bool?
    @ViewBuilder var badge: () -> Badge

    var body: some View {
        if isSelf || isDeleted {
            content
                .accessibilityIdentifier(identifier)
        } else {
            NavigationLink(value: UserProfileDestination(userId: userID, displayName: displayName)) {
                content
            }
            .buttonStyle(.plain)
            .lilyHoverable()
            .accessibilityIdentifier(identifier)
        }
    }

    private var isDeleted: Bool { deleted == true }

    private var content: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            if isDeleted {
                AvatarCircle(systemImage: Tombstone.symbol, size: DesignTokens.Layout.avatarMedium, tint: .secondary)
            } else {
                AvatarCircle(initials: displayName.initials, size: DesignTokens.Layout.avatarMedium)
            }
            Text(AppBranding.People.name(Tombstone.displayName(displayName, deleted: deleted), isSelf: isSelf))
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
