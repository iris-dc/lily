import SwiftUI

/// A group's chat room: the transcript over the aurora, the composer pinned to the bottom, the group's name and
/// member count in the bar and an info button that leads to the group. A direct conversation is titled with the other
/// person, has no member count and its info button leads to their profile. The tab bar hides while it is open.
struct ChatView: View {
    @State private var viewModel: ChatViewModel
    private let dependencies: AppDependencies
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss

    init(viewModel: ChatViewModel, dependencies: AppDependencies) {
        _viewModel = State(initialValue: viewModel)
        self.dependencies = dependencies
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
        .toolbarVisibility(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { infoButton }
        }
        .task { await viewModel.appear() }
        .onDisappear { Task { await viewModel.cancel() } }
        .onChange(of: scenePhase) {
            if scenePhase == .background { Task { await viewModel.sceneDidEnterBackground() } }
        }
        // Out of the group, or the group is gone: nothing left to show here.
        .onChange(of: viewModel.isGone) {
            if viewModel.isGone { dismiss() }
        }
    }

    /// The group's detail, or the other person's profile in a direct conversation (reached from the chat, so it offers
    /// no "Message" back into it); one identifier either way.
    @ViewBuilder private var infoButton: some View {
        if let counterpart = group.counterpart {
            NavigationLink(value: counterpart.profile(context: .fromChat)) {
                Label(AppBranding.profileTitle, systemImage: DesignTokens.Symbols.info)
            }
            .accessibilityIdentifier(AccessibilityIdentifiers.chatTitle)
        } else {
            NavigationLink(value: GroupInfoDestination(group: group)) {
                Label(AppBranding.Groups.title, systemImage: DesignTokens.Symbols.info)
            }
            .accessibilityIdentifier(AccessibilityIdentifiers.chatTitle)
        }
    }

    /// A spinner while the first page loads; the empty state for a room nobody has written in.
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
