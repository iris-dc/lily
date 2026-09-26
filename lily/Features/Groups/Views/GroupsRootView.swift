import SwiftUI

/// The Groups tab's root: Mine or Discover behind a toolbar picker, search and a type dropdown on Discover, "Join
/// with code" in the toolbar and a floating "+" that creates a group (or signs a guest in first).
struct GroupsRootView: View {
    private let dependencies: AppDependencies
    @State private var scope: GroupListScope
    @State private var mine: GroupListViewModel
    @State private var discover: GroupListViewModel
    @State private var presentedSheet: RootSheet?

    private enum RootSheet: String, Identifiable {
        case create, signIn, joinWithCode

        var id: String { rawValue }
    }

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        _scope = State(initialValue: GroupsContent(for: dependencies.sessionController.state).initialScope)
        _mine = State(initialValue: dependencies.makeGroupListViewModel(scope: .mine))
        _discover = State(initialValue: dependencies.makeGroupListViewModel(scope: .discover))
    }

    private var viewModel: GroupListViewModel { scope == .mine ? mine : discover }
    private var content: GroupsContent { GroupsContent(for: dependencies.sessionController.state) }

    var body: some View {
        @Bindable var discover = discover
        ContentScreen {
            // The button floats inside the safe area, so it sits above the floating tab bar rather than under it.
            ZStack(alignment: .bottomTrailing) {
                GroupListView(viewModel: viewModel,
                              content: content,
                              unread: dependencies.unreadCenter,
                              onOpen: { dependencies.navigation.open(chat: $0) },
                              onSignIn: { presentedSheet = .signIn })
                CreateGroupButton(action: presentCreate)
                    .padding(DesignTokens.Spacing.lg)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle(AppBranding.Groups.title)
        .toolbar { toolbarItems }
        .searchable(scope == .discover, text: $discover.query, prompt: AppBranding.Groups.discover)
        .groupDestinations(dependencies: dependencies, onGroupChange: discover.replace)
        // The only `SportEvent` destination on this stack (the group detail's Events segment pushes them).
        .navigationDestination(for: SportEvent.self) { event in
            EventDetailView(viewModel: dependencies.makeEventDetailViewModel(for: event) { _ in
                dependencies.eventChanges.recordChange()
            })
        }
        .task(id: scope) { await viewModel.loadIfStale() }
        .onDisappear { discover.cancel() }
        .sheet(item: $presentedSheet) { sheet in
            switch sheet {
            case .create:
                CreateGroupSheet(viewModel: dependencies.makeCreateGroupViewModel { _ in }, errorCenter: dependencies.errorCenter)
            case .signIn:
                SignInSheet(session: dependencies.sessionController, errorCenter: dependencies.errorCenter)
            case .joinWithCode:
                JoinWithCodeSheet(viewModel: dependencies.makeJoinWithCodeViewModel { _ in }, dependencies: dependencies)
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        // iOS 26 gives every toolbar item its own glass; the segmented picker already draws one.
        ToolbarItem(placement: .topBarTrailing) { scopePicker }
            .sharedBackgroundVisibility(.hidden)
        if scope == .discover {
            ToolbarItem(placement: .topBarTrailing) { GroupTypeFilterButton(viewModel: discover) }
        }
        ToolbarItem(placement: .topBarTrailing) { joinWithCodeButton }
    }

    private var scopePicker: some View {
        Picker(AppBranding.Groups.title, selection: $scope) {
            Text(AppBranding.Groups.mine).tag(GroupListScope.mine)
            Text(AppBranding.Groups.discover).tag(GroupListScope.discover)
        }
        .pickerStyle(.segmented)
        .fixedSize()
        .accessibilityIdentifier(AccessibilityIdentifiers.groupsScope)
    }

    private var joinWithCodeButton: some View {
        Button {
            presentedSheet = .joinWithCode
        } label: {
            Label(AppBranding.Groups.joinWithCode, systemImage: DesignTokens.Symbols.enterCode)
        }
        .accessibilityIdentifier(AccessibilityIdentifiers.groupsJoinCode)
    }

    /// Only a signed-in user can own a group; a guest is offered sign-in and comes back to the button afterwards.
    private func presentCreate() {
        if content == .myGroups {
            presentedSheet = .create
        } else {
            dependencies.logger.info(.auth, "Guest asked to create a group; showing sign-in")
            presentedSheet = .signIn
        }
    }
}

private extension View {
    /// The search field exists on Discover only; Mine is short enough to scan.
    @ViewBuilder
    func searchable(_ isEnabled: Bool, text: Binding<String>, prompt: String) -> some View {
        if isEnabled {
            searchable(text: text, prompt: prompt)
        } else {
            self
        }
    }
}

#Preview {
    NavigationStack {
        GroupsRootView(dependencies: .makeMock())
    }
}
