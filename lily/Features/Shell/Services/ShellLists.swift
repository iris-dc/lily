import Foundation

/// The lists the Home and Explore tabs draw, owned for the app's lifetime rather than by a tab's tree: each starts from
/// the snapshot the last run left (`ListSnapshotStore`), so a tab's first frame shows content; Explore's are loaded
/// by `ShellSync` right after launch, so the tab holds a fresh answer before it is first opened; and a tree rebuilt
/// for a new language, or a tab left and reopened, keeps what it had. Outliving the session, they clear with it, so
/// one account's lists never show for the next. A group's segments and Discover's own page keep view models of their
/// own: they are screens, built when they open.
final class ShellLists: SessionObserver {
    /// Home's own games and tournaments; Home loads them itself, being a signed-in user's start tab, and a guest is
    /// asked for nothing there.
    let homeEvents: EventListViewModel
    let homeTournaments: TournamentListViewModel
    /// Explore's list and its two carousels.
    let exploreEvents: EventListViewModel
    let discover: DiscoverGroupsViewModel
    let exploreTournaments: TournamentListViewModel

    init(homeEvents: EventListViewModel,
         homeTournaments: TournamentListViewModel,
         exploreEvents: EventListViewModel,
         discover: DiscoverGroupsViewModel,
         exploreTournaments: TournamentListViewModel) {
        self.homeEvents = homeEvents
        self.homeTournaments = homeTournaments
        self.exploreEvents = exploreEvents
        self.discover = discover
        self.exploreTournaments = exploreTournaments
    }

    /// What Explore does on appearance, done ahead of it: the loads with the position alongside, as the tab runs them
    /// (a list answered before the fix arrived asks once more itself), the carousels behind their flags. Within the
    /// lists' TTL a later run asks nothing.
    func loadExploreIfStale() async {
        async let events: Void = exploreEvents.loadIfStale()
        async let eventsPosition: Void = exploreEvents.loadUserLocation()
        async let groups: Void = loadDiscoverIfStale()
        async let tournaments: Void = loadExploreTournamentsIfStale()
        _ = await (events, eventsPosition, groups, tournaments)
    }

    /// Every list empties and forgets its loads; the snapshots they write while clearing are swept by the snapshot
    /// store, which the root registers after this.
    func sessionDidEnd() {
        homeEvents.clear()
        homeTournaments.clear()
        exploreEvents.clear()
        discover.clear()
        exploreTournaments.clear()
    }

    private func loadDiscoverIfStale() async {
        guard AppConfig.FeatureFlags.groups else { return }
        async let page: Void = discover.loadIfStale()
        async let position: Void = discover.loadUserLocation()
        _ = await (page, position)
    }

    private func loadExploreTournamentsIfStale() async {
        guard AppConfig.FeatureFlags.tournaments else { return }
        async let list: Void = exploreTournaments.loadIfStale()
        async let position: Void = exploreTournaments.loadUserLocation()
        _ = await (list, position)
    }
}
