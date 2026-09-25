import SwiftUI

/// A group's chat room: the transcript over the aurora, the composer pinned to the bottom, the group's name and
/// member count in the bar and an info button that leads to the group. The tab bar hides while it is open.
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
        .navigationSubtitle(AppBranding.Groups.members(group.memberCount))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarVisibility(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: GroupInfoDestination(group: group)) {
                    Label(AppBranding.Groups.title, systemImage: DesignTokens.Symbols.info)
                }
                .accessibilityIdentifier(AccessibilityIdentifiers.chatTitle)
            }
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

#Preview {
    let dependencies = AppDependencies.makeMock()
    NavigationStack {
        ChatView(viewModel: dependencies.makeChatViewModel(for: MockGroupFixtures.make(now: .now)[0]),
                 dependencies: dependencies)
    }
}
