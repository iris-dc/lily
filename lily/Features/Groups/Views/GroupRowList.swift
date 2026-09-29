import SwiftUI

/// The caller's groups as conversation rows with dividers, each opening what the container decides (the chat, or the
/// group while chat is off). Knows nothing about scrolling, so Home embeds it under its section title.
struct GroupRowList: View {
    let groups: [SportGroup]
    let unread: UnreadCenter
    let onOpen: (SportGroup) -> Void

    var body: some View {
        LazyVStack(spacing: 0) {
            ForEach(groups) { group in
                Button {
                    onOpen(group)
                } label: {
                    GroupRow(group: group, hasUnread: unread.hasUnread(groupID: group.id))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(AccessibilityIdentifiers.groupRow(group.id))
                Divider().padding(.leading, DesignTokens.Layout.avatarMedium + DesignTokens.Spacing.md)
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
