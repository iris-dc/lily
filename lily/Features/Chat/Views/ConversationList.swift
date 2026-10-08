import SwiftUI

/// The caller's conversations: the inbox pinned first, then the rooms (group rooms and direct conversations together,
/// most recently active first), with a long press on a room offering Clear chat or Delete chat for anyone who may
/// chat. Pull-to-refresh reloads the rooms and the inbox. The container decides what a tap does (push on a compact
/// width, select on a regular one) and which row is selected, so the Chats stack and the split view share one list.
struct ConversationList: View {
    let dependencies: AppDependencies
    /// The row drawn as selected (the split view's detail); `nil` on a compact width, where nothing stays selected.
    let selection: ConversationSelection?
    let onOpenInbox: () -> Void
    let onOpenRoom: (SportGroup) -> Void
    /// Asks the container to confirm a clear or delete of the room.
    let onClear: (SportGroup) -> Void

    private typealias Copy = AppBranding.Chats

    private var myGroups: MyGroupsStore { dependencies.myGroups }

    var body: some View {
        RefreshableScroll {
            await myGroups.reload()
            await dependencies.inbox.reload()
        } content: {
            LazyVStack(spacing: 0) {
                InboxRow(inbox: dependencies.inbox, isSelected: selection == .inbox, onOpen: onOpenInbox)
                    .padding(.horizontal, DesignTokens.Layout.screenMargin)
                AvatarRowDivider()
                rooms
            }
            .padding(.vertical, DesignTokens.Spacing.md)
            .padding(.bottom, DesignTokens.Spacing.xxl)
        }
    }

    @ViewBuilder private var rooms: some View {
        if !myGroups.groups.isEmpty {
            GroupRowList(groups: myGroups.groups,
                         unread: dependencies.unreadCenter,
                         selectedID: selectedRoomID,
                         rowMenu: rowMenu,
                         onOpen: onOpenRoom)
        } else if myGroups.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignTokens.Spacing.lg)
        } else {
            noRooms
        }
    }

    private var selectedRoomID: String? {
        if case .room(let id) = selection { return id }
        return nil
    }

    /// What a long press on a room offers: the same clear or delete item as the room's menu, for anyone who may chat.
    @ViewBuilder private func rowMenu(for group: SportGroup) -> some View {
        if GroupAccess(group: group, userID: dependencies.identity.currentUserID).canChat {
            ChatClearMenuItem(group: group) { onClear(group) }
        }
    }

    /// Nothing to chat in yet: the way out is a group, and groups are found on Explore.
    private var noRooms: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text(myGroups.loadFailed ? AppBranding.Home.groupsLoadFailed : Copy.noRooms)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if !myGroups.loadFailed {
                Button(Copy.noRoomsAction) { dependencies.navigation.selectedTab = .explore }
                    .lilyGlassButton(sizing: .fitted, labelColor: .lilyInk)
            }
        }
        .padding(.horizontal, DesignTokens.Layout.screenMargin)
        .padding(.vertical, DesignTokens.Spacing.lg)
    }
}

#Preview {
    let dependencies = AppDependencies.makeMock()
    ContentScreen {
        ConversationList(dependencies: dependencies,
                         selection: .room(id: MockGroupFixtures.kickersID),
                         onOpenInbox: {},
                         onOpenRoom: { _ in },
                         onClear: { _ in })
    }
}
