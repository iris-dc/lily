import SwiftUI

/// The Home root: the caller's groups as rows (each opening the group's detail) and the games they joined or host as
/// cards. Creating lives under the "+" on Explore, chats on the Chats tab. A guest is asked to sign in instead, and
/// nothing is requested for them; the loads run again for whoever signs in from here.
struct HomeView: View {
    private let dependencies: AppDependencies
    @State private var events: EventListViewModel
    @State private var tournaments: TournamentListViewModel

    private typealias Copy = AppBranding.Home

    /// What one run of the loads is for; a new caller or a game changed elsewhere starts another.
    private struct LoadKey: Hashable {
        let userID: String?
        let eventsVersion: Int
        let tournamentsVersion: Int
    }

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        _events = State(initialValue: dependencies.makeEventListViewModel(scope: .joined))
        _tournaments = State(initialValue: dependencies.makeTournamentListViewModel(scope: .mine))
    }

    private var content: HomeContent { HomeContent(for: dependencies.sessionController.state) }

    private var loadKey: LoadKey {
        LoadKey(userID: dependencies.sessionController.state.user?.id,
                eventsVersion: dependencies.eventChanges.version,
                tournamentsVersion: dependencies.tournamentChanges.version)
    }

    var body: some View {
        ContentScreen {
            switch content {
            case .signInPrompt:
                GuestSignInPrompt(symbolName: DesignTokens.Symbols.home,
                                  message: Copy.guestMessage,
                                  dependencies: dependencies)
            case .overview:
                HomeOverview(groups: dependencies.myGroups,
                             events: events,
                             tournaments: tournaments,
                             dependencies: dependencies)
            }
        }
        .navigationTitle(AppBranding.homeTitle)
        .groupDestinations(dependencies: dependencies, onTournamentChange: tournaments.replace)
        // The only `SportEvent` destination on this stack (the cards here and a group detail's Events segment push them).
        .navigationDestination(for: SportEvent.self) { event in
            EventDetailView(viewModel: dependencies.makeEventDetailViewModel(for: event, onChange: events.replace),
                            dependencies: dependencies)
        }
        .task(id: loadKey) { await loadIfStale() }
    }

    /// The caller's games and groups are theirs alone, so a guest asks for nothing. The three lists load at once, so
    /// the screen's spinner lasts one round trip and not three. The locals keep the child tasks from capturing the
    /// view: they capture the main-actor collaborators, which are `Sendable`.
    private func loadIfStale() async {
        guard content == .overview else { return }
        let events = events
        let tournaments = tournaments
        let myGroups = dependencies.myGroups
        async let games: Void = events.loadIfStale()
        async let groups: Void = Self.loadGroupsIfStale(myGroups)
        async let mine: Void = Self.loadTournamentsIfStale(tournaments)
        _ = await (games, groups, mine)
        await events.loadUserLocation()
        if AppConfig.FeatureFlags.tournaments { await tournaments.loadUserLocation() }
    }

    private static func loadGroupsIfStale(_ myGroups: MyGroupsStore) async {
        if AppConfig.FeatureFlags.groups { await myGroups.loadIfStale() }
    }

    private static func loadTournamentsIfStale(_ tournaments: TournamentListViewModel) async {
        if AppConfig.FeatureFlags.tournaments { await tournaments.loadIfStale() }
    }
}

#Preview {
    NavigationStack {
        HomeView(dependencies: .makeMock())
    }
}
