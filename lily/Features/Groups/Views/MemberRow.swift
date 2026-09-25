import SwiftUI

/// One member of a group: their mark, their name ("You" for the caller), and a badge for owners and admins.
struct MemberRow: View {
    let member: GroupMember
    let isSelf: Bool

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            AvatarCircle(initials: member.displayName.initials, size: DesignTokens.Layout.avatarMedium)
            Text(name)
                .font(.body)
                .lineLimit(1)
            Spacer(minLength: DesignTokens.Spacing.sm)
            if let symbol = roleSymbol {
                Label(member.role.displayName, systemImage: symbol)
                    .lilyChip(.regular)
                    .fixedSize()
            }
        }
        .padding(.vertical, DesignTokens.Spacing.xs)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(AccessibilityIdentifiers.memberRow(member.userId))
    }

    /// The caller's row says "You" once: the suffix is skipped when the name already is it (the mock's roster).
    private var name: String {
        guard isSelf, member.displayName != AppBranding.Groups.youSuffix else { return member.displayName }
        return AppBranding.Groups.caption([member.displayName, AppBranding.Groups.youSuffix])
    }

    private var roleSymbol: String? {
        switch member.role {
        case .owner: DesignTokens.Symbols.owner
        case .admin: DesignTokens.Symbols.admin
        case .member, .banned: nil
        }
    }
}

#Preview {
    ContentScreen {
        VStack {
            ForEach(MockGroupFixtures.roster(for: MockGroupFixtures.kickersID, now: .now)) {
                MemberRow(member: $0, isSelf: false)
            }
        }
        .padding()
    }
}
