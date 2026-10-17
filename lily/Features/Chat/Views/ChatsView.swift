import SwiftUI

/// The Chats root on a compact width: the conversations (`ConversationList`), each tap pushing the inbox or a room on
/// this stack; the rows ask for a clear or delete themselves. A guest is asked to sign in instead, and nothing is
/// requested for them; the loads run again for whoever signs in from here.
struct ChatsView: View {
    let dependencies: AppDependencies

    private typealias Copy = AppBranding.Chats

    private var content: HomeContent { HomeContent(for: dependencies.sessionController.state) }

    var body: some View {
        ContentScreen {
            switch content {
            case .signInPrompt:
                GuestSignInPrompt(symbolName: DesignTokens.Symbols.chat,
                                  message: Copy.guestMessage,
                                  dependencies: dependencies)
            case .overview:
                ConversationList(dependencies: dependencies,
                                 selection: nil,
                                 onOpenInbox: { dependencies.navigation.openInbox() },
                                 onOpenRoom: { dependencies.navigation.open(chat: $0) })
            }
        }
        .navigationTitle(AppBranding.chatsTitle)
        .conversationDestinations(dependencies: dependencies)
        .conversationLoads(dependencies: dependencies)
    }
}

/// What every run of the Chats loads is for; a new caller or a group changed elsewhere starts another.
private struct ConversationLoadKey: Hashable {
    let userID: String?
    let groupsVersion: Int
}

extension View {
    /// The destinations of a Chats stack: the group screens, the inbox and the stack's one `SportEvent` destination
    /// (a system row in a chat and a reminder in the inbox push games). The compact root and the split view's detail
    /// column register the same set, so a push lands wherever the Chats stack is.
    func conversationDestinations(dependencies: AppDependencies) -> some View {
        groupDestinations(dependencies: dependencies)
            .navigationDestination(for: InboxDestination.self) { _ in
                InboxView(viewModel: dependencies.makeInboxViewModel())
            }
            .navigationDestination(for: SportEvent.self) { event in
                EventDetailView(viewModel: dependencies.makeEventDetailViewModel(for: event) { _ in
                    dependencies.eventChanges.recordChange()
                }, dependencies: dependencies)
            }
    }

    /// Loads the rooms and the inbox for a signed-in caller once per caller and group change; a guest asks for nothing.
    func conversationLoads(dependencies: AppDependencies) -> some View {
        let key = ConversationLoadKey(userID: dependencies.sessionController.state.user?.id,
                                      groupsVersion: dependencies.groupChanges.version)
        return task(id: key) {
            // Nothing is asked before the pool confirmed the cached user; the requests need its token anyway.
            await dependencies.sessionController.restore()
            guard !Task.isCancelled, HomeContent(for: dependencies.sessionController.state) == .overview else { return }
            await dependencies.myGroups.loadIfStale()
            await dependencies.inbox.loadIfStale()
        }
    }
}

#Preview {
    NavigationStack {
        ChatsView(dependencies: .makeMock())
    }
}
