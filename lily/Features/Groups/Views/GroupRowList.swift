import SwiftUI

/// The caller's groups as conversation rows with dividers, each opening what the container decides (the chat on the
/// Chats tab, the group's detail on Home). Rows carry the unread dot only where they open the room, so `unread` is
/// passed there alone. Knows nothing about scrolling, so a screen embeds it under its own header.
struct GroupRowList: View {
    let groups: [SportGroup]
    var unread: UnreadCenter?
    let onOpen: (SportGroup) -> Void

    var body: some View {
        LazyVStack(spacing: 0) {
            ForEach(groups) { group in
                Button {
                    onOpen(group)
                } label: {
                    GroupRow(group: group, hasUnread: unread?.hasUnread(groupID: group.id) ?? false)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(AccessibilityIdentifiers.groupRow(group.id))
                AvatarRowDivider()
            }
        }
        .padding(.horizontal, DesignTokens.Layout.screenMargin)
    }
}

#Preview {
    ContentScreen {
        GroupRowList(groups: MockGroupFixtures.make(now: .now), unread: UnreadCenter()) { _ in }
    }
}
