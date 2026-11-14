import SwiftUI

/// The Home root: the caller's events, tournaments and groups behind a segmented picker, with a prominent create
/// button opening the creation wizard seeded with the visible segment's kind (a full-screen cover on a compact width,
/// a form sheet elsewhere, as Explore presents it). A guest is asked to sign in instead, and nothing is requested for
/// them; the loads run again for whoever signs in from here.
struct HomeView: View {
    let dependencies: AppDependencies

    private typealias Copy = AppBranding.Home

    /// Home's lists, owned by `ShellLists` for the app's lifetime: the first frame shows the last run's snapshot while
    /// the loads below run.
    private var events: EventListViewModel { dependencies.lists.homeEvents }
    private var tournaments: TournamentListViewModel { dependencies.lists.homeTournaments }

    /// The wizard behind the create button, made once per presentation and owned above both presenters, so a mid-flow
    /// width-class change re-hosts the same flow instead of destroying it.
    @State private var wizardModel: AppCreationWizardModel?
    @State private var presentedSheet: WizardOnlySheet?

    /// What one run of the loads is for; a new caller or a game changed elsewhere starts another.
    private struct LoadKey: Hashable {
        let userID: String?
        let eventsVersion: Int
        let tournamentsVersion: Int
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
                             dependencies: dependencies,
                             onCreate: presentCreate)
            }
        }
        .navigationTitle(AppBranding.homeTitle)
        .toolbar { ProfileCornerButton(dependencies: dependencies) }
        .groupDestinations(dependencies: dependencies, onTournamentChange: tournaments.replace)
        // The only `SportEvent` destination on this stack (the cards here and a group detail's Events segment push them).
        .navigationDestination(for: SportEvent.self) { event in
            EventDetailView(viewModel: dependencies.makeEventDetailViewModel(for: event, onChange: events.replace),
                            dependencies: dependencies)
        }
        .creationWizardPresenter(item: $presentedSheet,
                                 model: wizardModel,
                                 errorCenter: dependencies.errorCenter,
                                 onDismissed: wizardDismissed)
        .task(id: loadKey) { await loadIfStale() }
    }

    /// The create button's wizard, seeded with the visible segment's kind. The created thing lands where it lives:
    /// a game or a tournament in Home's own list and on its detail, a group on its detail (Home's list learns of it
    /// through the store).
    private func presentCreate(_ kind: CreationKind) {
        let navigation = dependencies.navigation
        let events = events
        let tournaments = tournaments
        wizardModel = dependencies.makeCreationWizardModel(
            seed: CreationSeed(kind: kind),
            onCreatedEvent: { event in
                events.add(event)
                navigation.open(event: event)
            },
            onCreatedGroup: { navigation.open(group: $0) },
            onCreatedTournament: { detail in
                // Inserted, not refetched: the by-user index is eventually consistent and could answer without the
                // new tournament; `add` still invalidates the sibling lists.
                tournaments.add(detail.tournament)
                navigation.open(tournament: detail.tournament.destination)
            })
        presentedSheet = .wizard
    }

    /// A real dismissal is where the flow's close is booked: the abandoned log, once and never after a create.
    private func wizardDismissed() {
        wizardModel?.noteClosed()
        wizardModel = nil
    }

    /// The caller's games and groups are theirs alone, so a guest asks for nothing, and nothing is asked before the pool
    /// confirmed the cached user (the requests need the token that check obtains anyway). The three lists load at once,
    /// so the screen's spinner lasts one round trip and not three. The locals keep the child tasks from capturing the
    /// view: they capture the main-actor collaborators, which are `Sendable`.
    private func loadIfStale() async {
        await dependencies.sessionController.restore()
        guard !Task.isCancelled, content == .overview else { return }
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
