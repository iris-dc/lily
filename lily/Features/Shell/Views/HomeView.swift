import SwiftUI

/// The Home root: the caller's groups as rows (each opening the group's detail) and the games they joined or host as
/// cards. Creating lives under the "+" on Explore, chats on the Chats tab. A guest is asked to sign in instead, and
/// nothing is requested for them; the loads run again for whoever signs in from here.
struct HomeView: View {
    private let dependencies: AppDependencies
    @State private var groups: GroupListViewModel
    @State private var events: EventListViewModel

    private typealias Copy = AppBranding.Home

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
            case .signInPrompt:
                GuestSignInPrompt(symbolName: DesignTokens.Symbols.home,
                                  message: Copy.guestMessage,
                                  dependencies: dependencies)
            case .overview:
                HomeOverview(groups: groups, events: events, dependencies: dependencies)
            }
        }
        .navigationTitle(AppBranding.homeTitle)
        .groupDestinations(dependencies: dependencies)
        // The only `SportEvent` destination on this stack (the cards here and a group detail's Events segment push them).
        .navigationDestination(for: SportEvent.self) { event in
            EventDetailView(viewModel: dependencies.makeEventDetailViewModel(for: event, onChange: events.replace))
        }
        .task(id: loadKey) { await loadIfStale() }
    }

    /// The caller's games and groups are theirs alone, so a guest asks for nothing.
    private func loadIfStale() async {
        guard content == .overview else { return }
        await events.loadIfStale()
        await events.loadUserLocation()
        if AppConfig.FeatureFlags.groups { await groups.loadIfStale() }
    }
}

#Preview {
    NavigationStack {
        HomeView(dependencies: .makeMock())
    }
}
