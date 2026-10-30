import Foundation
import Observation

/// Discover: pages through the public groups on its own, sends the user's position so the backend answers the groups
/// around it, works for guests too, and searches again after a group changed anywhere (`changes` moves on a join, a
/// leave or a create; "Joined" and the member counts on the cards are the server's answer). Mine is `MyGroupsStore`'s.
@Observable
final class DiscoverGroupsViewModel {
    /// Typed into the search bar; the search restarts `AppConfig.Groups.searchDebounce` after the last change.
    var query = "" {
        didSet { if oldValue != query { restartSearch(debounced: true) } }
    }
    /// Narrows the browse to one event type; applied at once.
    var typeFilter: EventType? {
        didSet { if oldValue != typeFilter { restartSearch(debounced: false) } }
    }
    /// The pages so far.
    private(set) var groups: [SportGroup] = []
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    private(set) var hasSearched = false
    /// Cursor of the next page; `nil` once the last page arrived.
    @ObservationIgnored private(set) var nextCursor: String?
    /// Bumped by every new search, so a page that answers for an older query or filter is dropped.
    @ObservationIgnored private var searchGeneration = 0
    @ObservationIgnored private var searchTask: Task<Void, Never>?
    /// Who the pages were fetched for; "Joined" on a card is the server's answer for that caller.
    @ObservationIgnored private(set) var searchedUserID: String?
    /// The group-changes version the pages were fetched at; a join, leave or create anywhere moves it.
    @ObservationIgnored private(set) var searchedChangesVersion: Int?
    /// The position the pages on screen were searched for (`Coordinate.coarse`, the rounding the backend receives);
    /// `nil` for none. Set by an answer only, so a search that failed or was cancelled leaves it truthful, and a browse
    /// made for another position than the user's now is stale.
    @ObservationIgnored private(set) var searchedPosition: Coordinate?
    /// Known once the location service answered; distances on the cards and the position a browse sends need it.
    private(set) var userLocation: Coordinate?
    /// Off for the carousel on Explore: the events list there reports its own failure, and a second popup would only
    /// repeat it.
    var reportsSearchFailures = true

    let changes: ChangeTracker
    let repository: any GroupRepository
    let identity: any IdentityProvider
    let locationService: any LocationService
    let errorCenter: ErrorCenter
    let recorder: any InteractionRecorder
    let logger: any Logging
    let sleep: Sleep
    let now: () -> Date
    /// Where a plain browse's first page is kept for the first frame of the next launch (the carousel on Explore); a
    /// no-op for Discover's own screen, which is built when it opens.
    private let snapshots: any ListSnapshotStore

    init(changes: ChangeTracker,
         repository: any GroupRepository,
         identity: any IdentityProvider,
         locationService: any LocationService,
         errorCenter: ErrorCenter,
         recorder: any InteractionRecorder,
         logger: any Logging,
         sleep: @escaping Sleep = systemSleep,
         now: @escaping () -> Date = { .now },
         snapshots: any ListSnapshotStore = NoOpListSnapshotStore()) {
        self.changes = changes
        self.repository = repository
        self.identity = identity
        self.locationService = locationService
        self.errorCenter = errorCenter
        self.recorder = recorder
        self.logger = logger
        self.sleep = sleep
        self.now = now
        self.snapshots = snapshots
        // A hint for the first frame, not an answer: `hasSearched` stays false, so the first appearance searches.
        groups = snapshots.load([SportGroup].self, for: Self.snapshotKey(for: identity.currentUserID)) ?? []
    }

    /// "Joined" on a card is one caller's answer, so the snapshot is kept under the caller it shows to.
    private static func snapshotKey(for userID: String?) -> ListSnapshotKey {
        ListSnapshotKey(list: AppConfig.Lists.discoverGroupsSnapshot, userID: userID)
    }

    /// A browse with nothing typed and no type chosen: the page the carousel shows, and the one worth a snapshot.
    private var isPlainBrowse: Bool { effectiveQuery == nil && typeFilter == nil }

    /// True until the first answer, so the empty state waits for it.
    var isInitialLoad: Bool { isLoading && !hasSearched }

    /// The search has answered and nothing matched.
    var nothingMatched: Bool { hasSearched && groups.isEmpty && !isLoading }

    var canLoadMore: Bool { nextCursor != nil && !isLoadingMore && !isLoading }

    /// The name prefix sent to the backend: trimmed, capped at what it accepts (counted in UTF-16 units, as Laurel
    /// does), `nil` when nothing was typed.
    var effectiveQuery: String? {
        query.nonBlankTrimmed?.prefix(wireLength: AppConfig.Groups.queryMaxLength)
    }

    /// What a browse sends: the user's position as the backend receives it. A name search is global and sends none.
    var browsePosition: Coordinate? {
        effectiveQuery == nil ? userLocation?.coarse : nil
    }

    /// Nothing searched yet, or the pages on screen were fetched for another caller, before a group changed anywhere,
    /// or for another position than the one a browse would send now.
    private var isStale: Bool {
        !hasSearched || searchedUserID != identity.currentUserID || searchedChangesVersion != changes.version
            || searchedPosition != browsePosition
    }

    private var requestScope: GroupScope {
        .discover(query: effectiveQuery, type: typeFilter)
    }

    /// Searches once per caller, again after a group changed anywhere or the position moved, and otherwise only on a
    /// new search or a refresh. A search already out is left to answer (it re-checks the position itself; a caller
    /// change leaves its page stale for the next appearance), so the tab opening during the launch's warm-up does not
    /// spend a second request and drop the first.
    func loadIfStale() async {
        if isStale, !isLoading { await search() }
    }

    /// The session ended: the next caller starts from nothing and a search still out is dropped when it answers
    /// (`ShellLists` calls it).
    func clear() {
        cancel()
        searchGeneration += 1
        isLoading = false
        groups = []
        nextCursor = nil
        hasSearched = false
        searchedUserID = nil
        searchedChangesVersion = nil
        searchedPosition = nil
    }

    /// Asks for the position on every appearance (the cache answers within its TTL). A browse answered for another
    /// position than the user's now (or none) is searched again, so the page is the one around the user; a search in
    /// flight notices the position itself when it answers (`search()`).
    func loadUserLocation() async {
        if let fix = await locationService.currentLocation() { userLocation = fix }
        guard hasSearched, !isLoading, searchedPosition != browsePosition else { return }
        logger.debug(.cache, "Discover searched for another position; searching again")
        await search()
    }

    /// Road distance from the user to the group's place, formatted; `nil` while the position is unknown or the group
    /// has no place.
    func distanceText(for group: SportGroup) -> String? {
        group.distance(from: userLocation)?.roadText()
    }

    /// Pull-to-refresh: always asks the backend.
    func refresh() async {
        await search()
    }

    /// Cancels a pending or running search; the view calls it when the screen goes away.
    func cancel() {
        searchTask?.cancel()
        searchTask = nil
    }

    /// Replaces the pages with the first one for the current query and type. A newer search started meanwhile wins:
    /// its generation differs, so this answer is dropped. A position that arrived or moved while the request was out
    /// earns one search right away, so the page around the user replaces the answer without waiting for the next
    /// appearance; a failure or a cancellation never does, so a backend that is down is not asked in a loop.
    func search() async {
        searchGeneration += 1
        let generation = searchGeneration
        isLoading = true
        let answered = await performSearch(near: browsePosition, generation: generation)
        guard generation == searchGeneration else { return }
        isLoading = false
        if answered, searchedPosition != browsePosition {
            logger.debug(.cache, "Position changed while Discover searched; searching again")
            await search()
        }
    }

    /// One request and its bookkeeping; answers whether this generation's page was taken. The caller and the
    /// group-changes version stamped on the page are read before the request, so a `group_updated`, a join or a sign-in
    /// landing while the page was out leaves it stale and the next appearance searches again; a sign-out meanwhile went
    /// through `clear()`, whose generation this page no longer matches, and the snapshot is written under the caller
    /// the page was fetched for.
    private func performSearch(near position: Coordinate?, generation: Int) async -> Bool {
        let userID = identity.currentUserID
        let version = changes.version
        do {
            let page = try await repository.groups(in: requestScope, cursor: nil, near: position)
            guard generation == searchGeneration else { return false }
            groups = page.items
            nextCursor = page.nextCursor
            hasSearched = true
            searchedUserID = userID
            searchedChangesVersion = version
            searchedPosition = position
            if isPlainBrowse { snapshots.save(groups, for: Self.snapshotKey(for: userID)) }
            recordSearch(resultCount: page.items.count)
            return true
        } catch {
            guard !AppError.isCancellation(error), generation == searchGeneration else { return false }
            logger.error(.groups, "Discover failed: \(error)")
            if reportsSearchFailures { errorCenter.report(error) }
            return false
        }
    }

    /// The next page, appended without repeating a group two pages both carry; it asks as the first page did, so the
    /// cursor is read against the same order.
    func loadMore() async {
        guard let cursor = nextCursor, canLoadMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        let generation = searchGeneration
        do {
            let page = try await repository.groups(in: requestScope, cursor: cursor, near: searchedPosition)
            guard generation == searchGeneration else { return }
            let known = Set(groups.map(\.id))
            groups += page.items.filter { !known.contains($0.id) }
            nextCursor = page.nextCursor
            logger.debug(.groups, "Discover page appended: \(page.items.count) groups")
        } catch {
            guard !AppError.isCancellation(error) else { return }
            logger.error(.groups, "Discover paging failed: \(error)")
            errorCenter.report(error)
        }
    }

    /// Starts a search after the debounce (typing) or at once (a filter change), cancelling the one pending.
    private func restartSearch(debounced: Bool) {
        cancel()
        searchTask = Task { [weak self, sleep] in
            if debounced {
                do { try await sleep(AppConfig.Groups.searchDebounce) } catch { return }
            }
            await self?.search()
        }
    }

    /// Ids and flags only: whether something was typed and how many groups matched, never the text.
    private func recordSearch(resultCount: Int) {
        let hasQuery = effectiveQuery != nil
        recorder.record(.groupSearchPerformed(hasQuery: hasQuery, resultCount: resultCount, at: now()))
        logger.info(.groups, "Discover loaded \(resultCount) groups (query: \(hasQuery), type: \(typeFilter?.wireName ?? "any"))")
    }
}
