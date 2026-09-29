import SwiftUI

/// The Home root: the caller's groups as conversation rows and the games they joined or host as cards, with "Join
/// with code" in the toolbar. Creating lives under the "+" on Explore. A guest is asked to sign in instead, and
/// nothing is requested for them; the loads run again for whoever signs in from here.
struct HomeView: View {
    private let dependencies: AppDependencies
    @State private var groups: GroupListViewModel
    @State private var events: EventListViewModel
    @State private var presentedSheet: HomeSheet?

    private typealias Copy = AppBranding.Home

    private enum HomeSheet: String, Identifiable {
        case joinWithCode, signIn

        var id: String { rawValue }
    }

    /// What one run of the loads is for; a new caller or a game changed elsewhere starts another.
    private struct LoadKey: Hashable {
        let userID: String?
        let eventsVersion: Int
    }

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        _groups = State(initialValue: dependencies.makeGroupListViewModel(scope: .mine))
        _events = State(initialValue: dependencies.makeEventListViewModel(scope: .joined))
    }

    private var content: HomeContent { HomeContent(for: dependencies.sessionController.state) }

    private var loadKey: LoadKey {
        LoadKey(userID: dependencies.sessionController.state.user?.id, eventsVersion: dependencies.eventChanges.version)
    }

    var body: some View {
        ContentScreen {
            switch content {
            case .signInPrompt: signInPrompt
            case .overview: HomeOverview(groups: groups, events: events, dependencies: dependencies)
            }
        }
        .navigationTitle(AppBranding.homeTitle)
        .toolbar {
            if AppConfig.FeatureFlags.groups {
                ToolbarItem(placement: .topBarTrailing) { joinWithCodeButton }
            }
        }
        .groupDestinations(dependencies: dependencies)
        // The only `SportEvent` destination on this stack (the cards here and a group detail's Events segment push them).
        .navigationDestination(for: SportEvent.self) { event in
            EventDetailView(viewModel: dependencies.makeEventDetailViewModel(for: event, onChange: events.replace))
        }
        .task(id: loadKey) { await loadIfStale() }
        .sheet(item: $presentedSheet) { sheet in
            switch sheet {
            case .joinWithCode:
                JoinWithCodeSheet(viewModel: dependencies.makeJoinWithCodeViewModel { _ in }, dependencies: dependencies)
            case .signIn:
                SignInSheet(session: dependencies.sessionController, errorCenter: dependencies.errorCenter)
            }
        }
    }

    /// The caller's games and groups are theirs alone, so a guest asks for nothing.
    private func loadIfStale() async {
        guard content == .overview else { return }
        await events.loadIfStale()
        await events.loadUserLocation()
        if AppConfig.FeatureFlags.groups { await groups.loadIfStale() }
    }

    private var signInPrompt: some View {
        EmptyStateView(symbolName: DesignTokens.Symbols.home,
                       title: AppBranding.guestProfileTitle,
                       message: Copy.guestMessage,
                       actionTitle: AppBranding.signInAction) {
            presentedSheet = .signIn
        }
    }

    /// Works for a guest too: the preview signs them in before the join. Text, not a glyph: a toolbar shows a `Label`
    /// as its icon alone, and a keyboard glyph says nothing about codes.
    private var joinWithCodeButton: some View {
        Button(AppBranding.Groups.joinWithCode) {
            presentedSheet = .joinWithCode
        }
        .accessibilityIdentifier(AccessibilityIdentifiers.groupsJoinCode)
    }
}

#Preview {
    NavigationStack {
        HomeView(dependencies: .makeMock())
    }
}
