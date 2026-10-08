import SwiftUI

/// A group's chat room: the transcript over the aurora, the composer pinned to the bottom, the group's name and
/// member count in the bar, an info button that leads to the group and a "more" menu whose one item clears the chat
/// for the caller after a confirmation. A direct conversation is titled with the other person, has no member count,
/// its info button leads to their profile and its menu reads "Delete chat". On a compact width the tab bar hides
/// while it is open; on a regular width the room sits in a split view's detail beside the tabs' top bar.
struct ChatView: View {
    @State private var viewModel: ChatViewModel
    /// The room awaiting the caller's word on a clear; `nil` while nothing is asked.
    @State private var clearing: SportGroup?
    private let dependencies: AppDependencies
    /// What leaves the screen once the room is gone: the pop by default, or clearing the split view's selection when
    /// the room is the detail column's root, where there is nothing to pop.
    private let onGone: (() -> Void)?
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var sizeClass

    init(viewModel: ChatViewModel, dependencies: AppDependencies, onGone: (() -> Void)? = nil) {
        _viewModel = State(initialValue: viewModel)
        self.dependencies = dependencies
        self.onGone = onGone
    }

    private var group: SportGroup { viewModel.group }

    var body: some View {
        ContentScreen {
            ChatTranscript(viewModel: viewModel, dependencies: dependencies)
                .overlay { placeholder }
                .safeAreaInset(edge: .bottom) { MessageComposer(viewModel: viewModel) }
        }
        .navigationTitle(group.name)
        .navigationSubtitle(ifPresent: viewModel.subtitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarVisibility(sizeClass == .compact ? .hidden : .automatic, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { infoButton }
            ToolbarItem(placement: .topBarTrailing) {
                ChatRoomMenu(group: group, userID: viewModel.identity.currentUserID) { clearing = group }
            }
        }
        .chatClearConfirmation(for: $clearing) { _ in
            Task { await viewModel.clearHistory() }
        }
        .task { await viewModel.appear() }
        .onDisappear { Task { await viewModel.cancel() } }
        .onChange(of: scenePhase) {
            if scenePhase == .background { Task { await viewModel.sceneDidEnterBackground() } }
        }
        // Out of the group, the group is gone, or the conversation was deleted: nothing left to show here.
        .onChange(of: viewModel.isGone) {
            guard viewModel.isGone else { return }
            if let onGone { onGone() } else { dismiss() }
        }
    }

    /// The group's detail, the other person's profile in a direct conversation (reached from the chat, so it offers
    /// no "Message" back into it), or the tournament of a tournament's room; one identifier either way.
    @ViewBuilder private var infoButton: some View {
        if let counterpart = group.counterpart {
            NavigationLink(value: counterpart.profile(context: .fromChat)) {
                Label(AppBranding.profileTitle, systemImage: DesignTokens.Symbols.info)
            }
            .accessibilityIdentifier(AccessibilityIdentifiers.chatTitle)
        } else if group.isTournamentRoom {
            NavigationLink(value: TournamentDestination(id: group.id, name: group.name)) {
                Label(AppBranding.Tournaments.tournament, systemImage: DesignTokens.Symbols.info)
            }
            .accessibilityIdentifier(AccessibilityIdentifiers.chatTitle)
        } else {
            NavigationLink(value: GroupInfoDestination(group: group)) {
                Label(AppBranding.Groups.title, systemImage: DesignTokens.Symbols.info)
            }
            .accessibilityIdentifier(AccessibilityIdentifiers.chatTitle)
        }
    }

    /// A spinner while the first page loads; the empty state for a room nobody has written in (or one just cleared).
    @ViewBuilder private var placeholder: some View {
        if viewModel.rows.isEmpty {
            if viewModel.isLoadingHistory {
                ProgressView()
            } else {
                EmptyStateView(symbolName: DesignTokens.Symbols.chat,
                               title: AppBranding.Chat.emptyTitle,
                               message: AppBranding.Chat.emptyMessage)
            }
        }
    }
}

private extension View {
    /// The subtitle when the room has one; a conversation's title alone names its two people.
    @ViewBuilder func navigationSubtitle(ifPresent subtitle: String?) -> some View {
        if let subtitle {
            navigationSubtitle(subtitle)
        } else {
            self
        }
    }
}

#Preview {
    let dependencies = AppDependencies.makeMock()
    NavigationStack {
        ChatView(viewModel: dependencies.makeChatViewModel(for: MockGroupFixtures.make(now: .now)[0]),
                 dependencies: dependencies)
    }
}
