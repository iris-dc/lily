import SwiftUI

/// One member of a group: their mark, their name ("You" for the caller), and a badge for owners and admins. Every row
/// but the caller's own opens the person's profile.
struct MemberRow: View {
    let member: GroupMember
    let isSelf: Bool

    var body: some View {
        PersonRow(userID: member.userId,
                  displayName: member.displayName,
                  isSelf: isSelf,
                  identifier: AccessibilityIdentifiers.memberRow(member.userId)) {
            if let symbol = roleSymbol {
                Label(member.role.displayName, systemImage: symbol)
                    .lilyChip(.regular)
            }
        }
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
    NavigationStack {
        ContentScreen {
            VStack {
                ForEach(MockGroupFixtures.roster(for: MockGroupFixtures.kickersID, now: .now)) {
                    MemberRow(member: $0, isSelf: false)
                }
            }
            .padding()
        }
    }
}
