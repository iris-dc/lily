import SwiftUI

/// The Chats root: the inbox pinned first, then the caller's rooms (group rooms and direct conversations together,
/// most recently active first), each opening its chat on this stack; a long press on a room offers Clear chat or
/// Delete chat, after the same confirmation as the room's own menu. A guest is asked to sign in instead, and nothing
/// is requested for them; the loads run again for whoever signs in from here. Pull-to-refresh reloads the rooms and
/// the inbox.
struct ChatsView: View {
    let dependencies: AppDependencies
    /// The room awaiting the caller's word on a clear; `nil` while nothing is asked.
    @State private var clearing: SportGroup?

    private typealias Copy = AppBranding.Chats

    /// What one run of the loads is for; a new caller or a group changed elsewhere starts another.
    private struct LoadKey: Hashable {
        let userID: String?
        let groupsVersion: Int
    }

    private var content: HomeContent { HomeContent(for: dependencies.sessionController.state) }
    private var myGroups: MyGroupsStore { dependencies.myGroups }
    private var inbox: InboxStore { dependencies.inbox }

    private var loadKey: LoadKey {
        LoadKey(userID: dependencies.sessionController.state.user?.id, groupsVersion: dependencies.groupChanges.version)
    }

    var body: some View {
        ContentScreen {
            switch content {
            case .signInPrompt:
                GuestSignInPrompt(symbolName: DesignTokens.Symbols.chat,
                                  message: Copy.guestMessage,
                                  dependencies: dependencies)
            case .overview:
                conversations
            }
        }
        .navigationTitle(AppBranding.chatsTitle)
        .groupDestinations(dependencies: dependencies)
        .navigationDestination(for: InboxDestination.self) { _ in
            InboxView(viewModel: dependencies.makeInboxViewModel())
        }
        // The only `SportEvent` destination on this stack (a system row in a chat, a reminder in the inbox push them).
        .navigationDestination(for: SportEvent.self) { event in
            EventDetailView(viewModel: dependencies.makeEventDetailViewModel(for: event) { _ in
                dependencies.eventChanges.recordChange()
            }, dependencies: dependencies)
        }
        .chatClearConfirmation(for: $clearing) { group in
            Task { await dependencies.makeChatHistoryClearer().clear(group) }
        }
        .task(id: loadKey) { await loadIfStale() }
    }

    private var conversations: some View {
        RefreshableScroll {
            await myGroups.reload()
            await inbox.reload()
        } content: {
            LazyVStack(spacing: 0) {
                InboxRow(inbox: inbox)
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
            GroupRowList(groups: myGroups.groups, unread: dependencies.unreadCenter, rowMenu: rowMenu) {
                dependencies.navigation.open(chat: $0)
            }
        } else if myGroups.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignTokens.Spacing.lg)
        } else {
            noRooms
        }
    }

    /// What a long press on a room offers: the same clear or delete item as the room's menu, for anyone who may chat.
    @ViewBuilder private func rowMenu(for group: SportGroup) -> some View {
        if GroupAccess(group: group, userID: dependencies.identity.currentUserID).canChat {
            ChatClearMenuItem(group: group) { clearing = group }
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

    /// The caller's rooms and inbox are theirs alone, so a guest asks for nothing.
    private func loadIfStale() async {
        guard content == .overview else { return }
        await myGroups.loadIfStale()
        await inbox.loadIfStale()
    }
}

#Preview {
    NavigationStack {
        ChatsView(dependencies: .makeMock())
    }
}
