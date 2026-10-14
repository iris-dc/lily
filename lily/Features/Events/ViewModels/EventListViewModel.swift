import Foundation
import Observation

/// Drives every list and map of events (explore, my events). Scope decides which slice is loaded. The filter, the
/// presentation switch and the statistics they produce live in `EventListViewModel+Filter.swift`.
@Observable
final class EventListViewModel {
    private(set) var events: [SportEvent] = []
    /// Narrows `events` to `visibleEvents` on device; the map and the list read the same slice.
    private(set) var filter: EventFilter
    private(set) var isLoading = false
    private(set) var userLocation: Coordinate?
    /// The filter as it was when the panel opened, `nil` while it is closed. Written by the filter extension.
    @ObservationIgnored var filterWhenPanelOpened: EventFilter?

    /// Shared with the filter extension in the sibling file, hence not `private`.
    let recorder: any InteractionRecorder
    let logger: any Logging
    let now: () -> Date
    /// The user's currency (`CurrencyStore.currencyCode`): what the price cap is typed and judged in.
    let currencyCode: () -> String

    private let scope: EventScope
    private let repository: any EventRepository
    private let identity: any IdentityProvider
    private let locationService: any LocationService
    private let changes: ChangeTracker
    private let errorCenter: ErrorCenter
    /// Where every filter change is kept for the next launch; a no-op for the lists that start from `.everything`.
    private let filterStore: any EventFilterStore
    /// TTL, the change counter, caller and (on Explore) position the content reflects, and the cooldown after a failed
    /// load.
    private var freshness = ContentFreshness.standard

    init(scope: EventScope,
         repository: any EventRepository,
         identity: any IdentityProvider,
         locationService: any LocationService,
         changes: ChangeTracker,
         errorCenter: ErrorCenter,
         recorder: any InteractionRecorder,
         logger: any Logging,
         now: @escaping () -> Date = { .now },
         currencyCode: @escaping () -> String,
         initialFilter: EventFilter = EventFilter(),
         filterStore: any EventFilterStore = NoOpEventFilterStore()) {
        self.filter = initialFilter
        self.currencyCode = currencyCode
        self.scope = scope
        self.repository = repository
        self.identity = identity
        self.locationService = locationService
        self.changes = changes
        self.errorCenter = errorCenter
        self.filterStore = filterStore
        self.recorder = recorder
        self.logger = logger
        self.now = now
    }

    /// The very first load, before any result exists. Later loads keep the current content (and its refresh spinner) on screen.
    var isInitialLoad: Bool { isLoading && !freshness.hasLoaded && !loadFailed }
    /// What a segment drawing this list shows now.
    var listState: ListState { ListState(isInitialLoad: isInitialLoad, isEmpty: visibleEvents.isEmpty, loadFailed: loadFailed) }

    /// True from a failed load until the next successful one, so the screen can say so instead of "nothing yet".
    var loadFailed: Bool { freshness.loadFailed }

    /// An answer landed at least once since the last reset; `loadFailed` is the other way a load ends.
    var hasLoaded: Bool { freshness.hasLoaded }

    /// Distance is judged from the user's position; while that is unknown the distance criterion is skipped. The price
    /// cap is judged in the user's currency, read on every pass so a change on Profile applies at once.
    var visibleEvents: [SportEvent] {
        let currency = currencyCode()
        return events.filter { filter.matches($0, from: userLocation, currencyCode: currency) }
    }

    /// The one way views change the filter, so every change is logged, kept for the next launch and the filter stays
    /// `private(set)`.
    func updateFilter(_ change: (inout EventFilter) -> Void) {
        change(&filter)
        filterStore.save(filter)
        logger.debug(.events, "Filter changed; active: \(filter.isActive), visible: \(visibleEvents.count) of \(events.count)")
    }

    /// Loads once per `AppConfig.Lists.staleAfter`, or sooner when another screen changed an event meanwhile,
    /// the caller changed (sign-in or sign-out; `isJoined` is per caller) or the position is not the one Explore
    /// content was loaded for (it became known after a load without one, or the user moved; the backend orders by
    /// distance), so a tab that reappears reuses what it already has.
    /// A failed load is retried only after `AppConfig.Lists.retryAfterFailure`, so switching tabs while the backend
    /// is down does not hammer it, unless an event changed elsewhere or the caller changed meanwhile, which proves
    /// the backend is up and the answer different; `load()` (pull-to-refresh) never waits.
    func loadIfStale() async {
        guard !isWaitingToRetry else {
            logger.debug(.cache, "Events for scope \(scope) failed to load recently; not retrying yet")
            return
        }
        guard let reason = stalenessReason else {
            logger.debug(.cache, "Events for scope \(scope) are fresh; skipping reload")
            return
        }
        logger.debug(.cache, "Events for scope \(scope) are stale (\(reason)); reloading")
        await load()
    }

    /// Always asks the repository (pull-to-refresh); a call made while one is in flight is dropped. Whatever landed
    /// while the request was out (a join or create through `replace`/`add`, a sign-in, on Explore a position that
    /// arrived or moved) may be missing from the answer, so it earns one reload right away. Bounded: only such a
    /// landing leaves a fresh answer stale, and a failed or cancelled load earns nothing.
    func load() async {
        guard !isLoading else { return }
        isLoading = true
        let succeeded = await performLoad(near: requestPosition)
        isLoading = false
        if succeeded, let reason = stalenessReason {
            logger.debug(.cache, "Events for scope \(scope): \(reason) while loading; reloading")
            await load()
        }
    }

    /// Takes the event the detail screen just changed, so the list is right on the way back without a round trip:
    /// Explore updates the row in place (its relevance order cannot be guessed on device, so it never takes a game it
    /// does not hold); a list in start order re-inserts the row by start, drops a game it no longer lists and inserts
    /// one it lists but did not hold yet (a join made from a group's segment on the Home stack reaches Home's games at
    /// once). Every other list reloads on its next appearance; this one already shows the change.
    func replace(_ event: SportEvent) {
        if let index = events.firstIndex(where: { $0.id == event.id }) {
            if scope == .upcoming {
                events[index] = event
            } else {
                events.remove(at: index)
                if listsByStart(event) { insertByStart(event) }
            }
        } else if listsByStart(event) {
            insertByStart(event)
        }
        recordOwnChange("Event \(event.id) replaced in scope \(scope)")
    }

    /// Takes an event just created from this screen so it shows without a round trip: first on Explore, whose order
    /// is the backend's relevance for the caller and where their own new game belongs on top, unless its group is
    /// private (the backend never lists one there, so neither does this list); by start time on a joined-only list,
    /// which stays chronological and takes it only when the caller participates (the host always does), and on a
    /// group's list, which takes only that group's games. Recorded like `replace`, so every other list reloads on its
    /// next appearance; repeated for one id, a no-op.
    func add(_ event: SportEvent) {
        guard !events.contains(where: { $0.id == event.id }) else {
            logger.debug(.cache, "Event \(event.id) already in scope \(scope); add ignored")
            return
        }
        switch scope {
        case .upcoming where event.isListed:
            events.insert(event, at: 0)
        case .upcoming:
            break
        case .joined, .group:
            if listsByStart(event) { insertByStart(event) }
        }
        recordOwnChange("Event \(event.id) added to scope \(scope)")
    }

    /// Whether a list in start order lists `event`, held or not: Home the caller's own games, a group's Events that
    /// group's games (one the caller left stays). Explore's relevance order cannot be guessed on device, so it never
    /// takes a game it does not hold.
    private func listsByStart(_ event: SportEvent) -> Bool {
        switch scope {
        case .upcoming: false
        case .joined: event.participates
        case .group(let id): event.group?.id == id
        }
    }

    private func insertByStart(_ event: SportEvent) {
        events.insert(event, at: events.firstIndex { $0.startsAt > event.startsAt } ?? events.endIndex)
    }

    /// This list already shows the change it applied; every other list reloads on its next appearance.
    private func recordOwnChange(_ what: String) {
        changes.recordChange()
        freshness.acknowledge(version: changes.version)
        logger.debug(.cache, "\(what); sibling lists invalidated")
    }

    /// Asks for the position on every appearance: the cache in front of CoreLocation answers within its TTL, so a tab
    /// that reappears within minutes costs nothing and one that reappears later follows the user. Location is optional
    /// context: without a fix the UI simply omits distances, and a miss after a fix keeps the last known position rather
    /// than blanking them. Explore content loaded for another position (or none) is stale then (see `loadIfStale`); a
    /// load in flight notices the position itself when it finishes.
    func loadUserLocation() async {
        let before = userLocation
        if let fix = await locationService.currentLocation() {
            userLocation = fix
        }
        if userLocation != before {
            logger.info(.location, before == nil ? "User location available" : "User location changed")
        } else {
            logger.debug(.location, userLocation == nil ? "No user location" : "User location unchanged")
        }
        if positionReason != nil, !isLoading {
            await loadIfStale()
        }
    }

    /// For the return to the foreground, the one moment permission may have changed (Settings): a remembered "no fix"
    /// is dropped first, so the request really asks CoreLocation instead of hitting the cache.
    func refreshUserLocation() async {
        locationService.forgetMissingFix()
        await loadUserLocation()
    }

    /// One request and its bookkeeping; answers whether it succeeded. Version and caller are taken before the request:
    /// a change or a sign-in landing mid-flight may be missing from the answer, and must reload.
    private func performLoad(near position: Coordinate?) async -> Bool {
        let version = changes.version
        let userID = identity.currentUserID
        do {
            events = try await repository.events(in: scope, near: position)
            freshness.recordSuccess(at: now(), version: version, userID: userID, position: position)
            logger.info(.events, "Loaded \(events.count) events for scope \(scope); with position: \(position != nil)")
            return true
        } catch {
            guard !AppError.isCancellation(error) else {
                logger.debug(.events, "Loading events cancelled for scope \(scope)")
                return false
            }
            freshness.recordFailure(at: now(), version: version, userID: userID)
            logger.error(.events, "Loading events failed for scope \(scope): \(error)")
            errorCenter.report(error)
            return false
        }
    }

    /// Only Explore is ordered by distance; Home is the caller's own games, in start order.
    private var requestPosition: Coordinate? { scope == .upcoming ? userLocation : nil }

    /// Why the user's position makes Explore content stale (`ContentFreshness.positionReason`); Home sends none.
    private var positionReason: String? { freshness.positionReason(for: requestPosition) }

    private var isWaitingToRetry: Bool {
        freshness.isWaitingToRetry(now: now(), version: changes.version, userID: identity.currentUserID)
    }

    /// Why the content must be reloaded, or `nil` while it can be reused: the shared rules first, then the position
    /// only Explore sends.
    private var stalenessReason: String? {
        freshness.stalenessReason(now: now(),
                                  version: changes.version,
                                  userID: identity.currentUserID,
                                  position: requestPosition)
    }
}
