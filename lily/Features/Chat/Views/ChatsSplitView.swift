import SwiftUI

/// The Chats tab on a regular width: the conversations in the sidebar column, the selected one in the detail column,
/// side by side, so a room stays open while the next is picked. The detail is the one `NavigationStack` bound to
/// `AppNavigation.chatPath`, so a group's info, a profile or a game pushed from a room lands beside the list; a
/// conversation opened from elsewhere in the app (a group's "Open chat", an accepted invite) selects itself here.
struct ChatsSplitView: View {
    let dependencies: AppDependencies
    /// The room awaiting the caller's word on a clear; `nil` while nothing is asked.
    @State private var clearing: SportGroup?

    /// False once the selected room left Mine (left, deleted, a conversation cleared); the inbox is always available.
    private var selectionIsAvailable: Bool {
        dependencies.navigation.selectedConversation?.isAvailable(in: dependencies.myGroups.groups) ?? true
    }

    var body: some View {
        @Bindable var navigation = dependencies.navigation
        NavigationSplitView(columnVisibility: .constant(.all)) {
            ContentScreen {
                ConversationList(dependencies: dependencies,
                                 selection: navigation.selectedConversation,
                                 onOpenInbox: { navigation.openInbox() },
                                 onOpenRoom: { navigation.open(chat: $0) },
                                 onClear: { clearing = $0 })
            }
            .navigationTitle(AppBranding.chatsTitle)
            .navigationSplitViewColumnWidth(min: DesignTokens.Layout.chatsSidebarMinWidth,
                                            ideal: DesignTokens.Layout.chatsSidebarIdealWidth,
                                            max: DesignTokens.Layout.chatsSidebarMaxWidth)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(AccessibilityIdentifiers.chatsSidebar)
        } detail: {
            NavigationStack(path: $navigation.chatPath) {
                ConversationDetail(selection: navigation.selectedConversation, dependencies: dependencies)
                    .conversationDestinations(dependencies: dependencies)
            }
        }
        .navigationSplitViewStyle(.balanced)
        .chatClearConfirmation(for: $clearing) { group in
            Task { await dependencies.makeChatHistoryClearer().clear(group) }
        }
        .conversationLoads(dependencies: dependencies)
        // The detail falls back to the empty state by itself, but the selection must go too, or the room would come
        // back into the detail on its own the moment Mine lists it again (a cleared conversation the other side writes
        // to); `ChatView.onGone` cannot do it, since the room leaves Mine before `isGone` flips and the view is gone.
        // `initial`, because the room may have left while the tab was compact (a Split View third) and no split view
        // was watching.
        .onChange(of: selectionIsAvailable, initial: true) {
            if !selectionIsAvailable { navigation.selectedConversation = nil }
        }
    }
}

/// The detail column's root: the inbox, the selected room (re-created per room, so the chat's appear and cancel run
/// for each), or the empty state while nothing is chosen or the chosen room is no longer the caller's.
private struct ConversationDetail: View {
    let selection: ConversationSelection?
    let dependencies: AppDependencies

    private typealias Copy = AppBranding.Chats

    var body: some View {
        switch selection {
        case .inbox:
            InboxView(viewModel: dependencies.makeInboxViewModel())
                .id(ConversationSelection.inbox)
        case .room(let id):
            if let group = dependencies.myGroups.groups.first(where: { $0.id == id }) {
                ChatView(viewModel: dependencies.makeChatViewModel(for: group),
                         dependencies: dependencies,
                         onGone: { dependencies.navigation.selectedConversation = nil })
                    .id(id)
            } else {
                nothingChosen
            }
        case nil:
            nothingChosen
        }
    }

    private var nothingChosen: some View {
        ContentScreen {
            EmptyStateView(symbolName: DesignTokens.Symbols.chat,
                           title: Copy.pickConversationTitle,
                           message: Copy.pickConversationMessage)
                .readableColumn()
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityIdentifiers.chatsNothingChosen)
    }
}

#Preview {
    ChatsSplitView(dependencies: .makeMock())
}
