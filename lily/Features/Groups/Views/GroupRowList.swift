import SwiftUI

/// The caller's groups as conversation rows with dividers, each opening what the container decides (the chat on the
/// Chats tab, the group's detail on Home). Rows carry the unread dot only where they open the room, so `unread` is
/// passed there alone, and a context menu only where the container gives one (Chats: clear or delete the chat; Home:
/// none). The row of `selectedID` is washed as the one a split view's detail shows. Knows nothing about scrolling, so
/// a screen embeds it under its own header.
struct GroupRowList<RowMenu: View>: View {
    let groups: [SportGroup]
    let unread: UnreadCenter?
    let selectedID: String?
    private let rowMenu: ((SportGroup) -> RowMenu)?
    let onOpen: (SportGroup) -> Void

    /// Rows whose long press offers `rowMenu`.
    init(groups: [SportGroup],
         unread: UnreadCenter? = nil,
         selectedID: String? = nil,
         @ViewBuilder rowMenu: @escaping (SportGroup) -> RowMenu,
         onOpen: @escaping (SportGroup) -> Void) {
        self.groups = groups
        self.unread = unread
        self.selectedID = selectedID
        self.rowMenu = rowMenu
        self.onOpen = onOpen
    }

    var body: some View {
        LazyVStack(spacing: 0) {
            ForEach(groups) { group in
                row(for: group)
                AvatarRowDivider()
            }
        }
        .padding(.horizontal, DesignTokens.Layout.screenMargin)
    }

    /// The context menu is attached only when there is one: an empty menu would still open on a long press.
    @ViewBuilder private func row(for group: SportGroup) -> some View {
        let button = Button {
            onOpen(group)
        } label: {
            GroupRow(group: group, hasUnread: unread?.hasUnread(groupID: group.id) ?? false)
                .selectedRowBackground(group.id == selectedID)
        }
        .buttonStyle(.plain)
        .lilyHoverable()
        .accessibilityIdentifier(AccessibilityIdentifiers.groupRow(group.id))
        if let rowMenu {
            button.contextMenu { rowMenu(group) }
        } else {
            button
        }
    }
}

extension GroupRowList where RowMenu == EmptyView {
    /// Rows without a context menu (Home, where a row opens the detail).
    init(groups: [SportGroup], unread: UnreadCenter? = nil, onOpen: @escaping (SportGroup) -> Void) {
        self.groups = groups
        self.unread = unread
        self.selectedID = nil
        self.rowMenu = nil
        self.onOpen = onOpen
    }
}

#Preview {
    ContentScreen {
        GroupRowList(groups: MockGroupFixtures.make(now: .now), unread: UnreadCenter()) { _ in }
    }
}
