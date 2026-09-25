import Foundation
import Observation

/// The groups list behind the Mine | Discover picker. Mine is a projection over `MyGroupsStore`, which owns the
/// caller's groups for the app's lifetime; Discover pages through the public groups on its own (see the `+Discover`
/// file) and works for guests too.
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

    let store: MyGroupsStore
    let repository: any GroupRepository
    let identity: any IdentityProvider
    let errorCenter: ErrorCenter
    let recorder: any InteractionRecorder
    let logger: any Logging
    let sleep: Sleep
    let now: () -> Date

    init(scope: GroupListScope,
         store: MyGroupsStore,
         repository: any GroupRepository,
         identity: any IdentityProvider,
         errorCenter: ErrorCenter,
         recorder: any InteractionRecorder,
         logger: any Logging,
         sleep: @escaping Sleep = systemSleep,
         now: @escaping () -> Date = { .now }) {
        self.scope = scope
        self.store = store
        self.repository = repository
        self.identity = identity
        self.errorCenter = errorCenter
        self.recorder = recorder
        self.logger = logger
        self.sleep = sleep
        self.now = now
    }

    var groups: [SportGroup] {
        switch scope {
        case .mine: store.groups
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
        case .mine: store.isLoading && store.groups.isEmpty
        case .discover: isLoadingDiscover && !hasSearched
        }
    }

    /// Mine follows the store's staleness rules; Discover loads once per caller and then only on a new search or a
    /// refresh.
    func loadIfStale() async {
        switch scope {
        case .mine: await store.loadIfStale()
        case .discover: if !hasSearched || searchedUserID != identity.currentUserID { await search() }
        }
    }

    /// Pull-to-refresh: always asks the backend.
    func refresh() async {
        switch scope {
        case .mine: await store.reload()
        case .discover: await search()
        }
    }

    /// A group as the detail screen just changed it (a join from Discover shows "Joined" on the way back). Mine is
    /// updated by the detail through the store.
    func replace(_ group: SportGroup) {
        guard let index = discovered.firstIndex(where: { $0.id == group.id }) else { return }
        discovered[index] = group
    }

    /// Cancels a pending or running search; the view calls it when the screen goes away.
    func cancel() {
        searchTask?.cancel()
        searchTask = nil
    }
}
