import Foundation
import Observation

/// The groups lists: Mine (Home's rows) is a projection over `MyGroupsStore.communities`, the store owning the
/// caller's groups for the app's lifetime (its direct conversations are the Chats tab's, never rows here); Discover
/// pages through the public groups on its own (see the `+Discover` file), sends the user's position so the backend
/// answers the groups around it, and works for guests too.
@Observable
final class GroupListViewModel {
    let scope: GroupListScope
    /// Typed into the search bar; Discover reloads `AppConfig.Groups.searchDebounce` after the last change.
    var query = "" {
        didSet { if oldValue != query { restartSearch(debounced: true) } }
    }
    /// Narrows Discover to one event type; applied at once.
    var typeFilter: EventType? {
        didSet { if oldValue != typeFilter { restartSearch(debounced: false) } }
    }
    /// Discover's pages so far; Mine reads the store. Set from the `+Discover` file, so not `private(set)`.
    var discovered: [SportGroup] = []
    var isLoadingDiscover = false
    var isLoadingMore = false
    var hasSearched = false
    /// Cursor of the next Discover page; `nil` once the last page arrived.
    @ObservationIgnored var nextCursor: String?
    /// Bumped by every new search, so a page that answers for an older query or filter is dropped.
    @ObservationIgnored var searchGeneration = 0
    @ObservationIgnored var searchTask: Task<Void, Never>?
    /// Who the Discover pages were fetched for; "Joined" on a card is the server's answer for that caller.
    @ObservationIgnored var searchedUserID: String?
    /// The group-changes version the Discover pages were fetched at; a join, leave or create anywhere moves it.
    @ObservationIgnored var searchedChangesVersion: Int?
    /// The position the Discover pages on screen were searched for (`Coordinate.coarse`, the rounding the backend
    /// receives); `nil` for none. Set by an answer only, so a search that failed or was cancelled leaves it truthful,
    /// and a browse made for another position than the user's now is stale.
    @ObservationIgnored var searchedPosition: Coordinate?
    /// Known once the location service answered; distances on the cards and the position Discover sends need it.
    private(set) var userLocation: Coordinate?
    /// Off for the carousel on Explore: the events list there reports its own failure, and a second popup would only
    /// repeat it.
    var reportsSearchFailures = true

    let store: MyGroupsStore
    let repository: any GroupRepository
    let identity: any IdentityProvider
    let locationService: any LocationService
    let errorCenter: ErrorCenter
    let recorder: any InteractionRecorder
    let logger: any Logging
    let sleep: Sleep
    let now: () -> Date

    init(scope: GroupListScope,
         store: MyGroupsStore,
         repository: any GroupRepository,
         identity: any IdentityProvider,
         locationService: any LocationService,
         errorCenter: ErrorCenter,
         recorder: any InteractionRecorder,
         logger: any Logging,
         sleep: @escaping Sleep = systemSleep,
         now: @escaping () -> Date = { .now }) {
        self.scope = scope
        self.store = store
        self.repository = repository
        self.identity = identity
        self.locationService = locationService
        self.errorCenter = errorCenter
        self.recorder = recorder
        self.logger = logger
        self.sleep = sleep
        self.now = now
    }

    var groups: [SportGroup] {
        switch scope {
        case .mine: store.communities
        case .discover: discovered
        }
    }

    var isLoading: Bool {
        switch scope {
        case .mine: store.isLoading
        case .discover: isLoadingDiscover
        }
    }

    /// Mine shows a refreshable "couldn't load" state after a failed load; a failed Discover search shows the popup only.
    var loadFailed: Bool {
        switch scope {
        case .mine: store.loadFailed
        case .discover: false
        }
    }

    /// True until something was loaded, so the empty state waits for the first answer.
    var isInitialLoad: Bool {
        switch scope {
        case .mine: store.isLoading && store.communities.isEmpty
        case .discover: isLoadingDiscover && !hasSearched
        }
    }

    /// Mine follows the store's staleness rules; Discover loads once per caller, again after a group changed anywhere
    /// ("Joined" and member counts are the server's answer), and otherwise only on a new search or a refresh.
    func loadIfStale() async {
        switch scope {
        case .mine: await store.loadIfStale()
        case .discover: if isDiscoverStale { await search() }
        }
    }

    private var isDiscoverStale: Bool {
        !hasSearched || searchedUserID != identity.currentUserID || searchedChangesVersion != store.changesVersion
            || searchedPosition != discoverPosition
    }

    /// Asks for the position on every appearance (the cache answers within its TTL). A Discover browse answered for
    /// another position than the user's now (or none) is searched again, so the page is the one around the user; a
    /// search in flight notices the position itself when it answers (`search()`), and Mine never searches.
    func loadUserLocation() async {
        if let fix = await locationService.currentLocation() { userLocation = fix }
        guard scope == .discover, hasSearched, !isLoadingDiscover, searchedPosition != discoverPosition else { return }
        logger.debug(.cache, "Discover searched for another position; searching again")
        await search()
    }

    /// Road distance from the user to the group's place, formatted; `nil` while the position is unknown or the group
    /// has no place.
    func distanceText(for group: SportGroup) -> String? {
        group.distance(from: userLocation)?.roadText
    }

    /// Pull-to-refresh: always asks the backend.
    func refresh() async {
        switch scope {
        case .mine: await store.reload()
        case .discover: await search()
        }
    }

    /// Cancels a pending or running search; the view calls it when the screen goes away.
    func cancel() {
        searchTask?.cancel()
        searchTask = nil
    }
}
