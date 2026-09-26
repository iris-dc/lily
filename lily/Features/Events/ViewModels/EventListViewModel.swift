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

    private let scope: EventScope
    private let repository: any EventRepository
    private let identity: any IdentityProvider
    private let locationService: any LocationService
    private let changes: ChangeTracker
    private let errorCenter: ErrorCenter
    /// TTL, the change counter and caller the content reflects, and the cooldown after a failed load.
    private var freshness = ContentFreshness(staleAfter: AppConfig.Events.listStaleAfter,
                                             retryAfterFailure: AppConfig.Events.retryAfterFailure)
    /// The position the current content was asked for, as `Coordinate.coarse` (the rounding the backend, which orders
    /// by distance, receives); `nil` after a load without one. Explore content for another position than the user's
    /// now is stale.
    private var loadedPosition: Coordinate?

    init(scope: EventScope,
         repository: any EventRepository,
         identity: any IdentityProvider,
         locationService: any LocationService,
         changes: ChangeTracker,
         errorCenter: ErrorCenter,
         recorder: any InteractionRecorder,
         logger: any Logging,
         now: @escaping () -> Date = { .now },
         initialFilter: EventFilter = EventFilter()) {
        self.filter = initialFilter
        self.scope = scope
        self.repository = repository
        self.identity = identity
        self.locationService = locationService
        self.changes = changes
        self.errorCenter = errorCenter
        self.recorder = recorder
        self.logger = logger
        self.now = now
    }

    /// The very first load, before any result exists. Later loads keep the current content (and its refresh spinner) on screen.
    var isInitialLoad: Bool { isLoading && !freshness.hasLoaded && !loadFailed }

    /// True from a failed load until the next successful one, so the screen can say so instead of "nothing yet".
    var loadFailed: Bool { freshness.loadFailed }

    /// Distance is judged from the user's position; while that is unknown the distance criterion is skipped.
    var visibleEvents: [SportEvent] { events.filter { filter.matches($0, from: userLocation) } }

    /// The one way views change the filter, so every change is logged and the filter stays `private(set)`.
    func updateFilter(_ change: (inout EventFilter) -> Void) {
        change(&filter)
        logger.debug(.events, "Filter changed; active: \(filter.isActive), visible: \(visibleEvents.count) of \(events.count)")
    }

    /// Loads once per `AppConfig.Events.listStaleAfter`, or sooner when another screen changed an event meanwhile,
    /// the caller changed (sign-in or sign-out; `isJoined` is per caller) or the position is not the one the Explore
    /// content was loaded for (it became known after a load without one, or the user moved; the backend orders by
    /// distance), so a tab that reappears reuses what it already has.
    /// A failed load is retried only after `AppConfig.Events.retryAfterFailure`, so switching tabs while the backend
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

    /// Always asks the repository (pull-to-refresh). A call made while one is in flight is dropped. Explore sends the
    /// user's position when known; one that arrived or moved while the request was out earns one reload right away, so
    /// the backend's order for where the user is replaces the answer without waiting for the next appearance.
    func load() async {
        guard !isLoading else { return }
        isLoading = true
        let succeeded = await performLoad(near: requestPosition)
        isLoading = false
        if succeeded, let reason = positionReason {
            logger.debug(.cache, "Events for scope \(scope): \(reason) while loading; reloading")
            await load()
        }
    }

    /// Takes the event the detail screen just changed. Applied in place, so the list is right on the way back without
    /// a round trip; a joined-only list drops an event the user has left. The change is recorded so every other list
    /// (My Events after a join on Explore) reloads on its next appearance; this one already shows it and does not.
    func replace(_ event: SportEvent) {
        if scope == .joined && !event.participates {
            events.removeAll { $0.id == event.id }
        } else if let index = events.firstIndex(where: { $0.id == event.id }) {
            events[index] = event
        }
        changes.recordChange()
        freshness.acknowledge(version: changes.version)
        logger.debug(.cache, "Event \(event.id) replaced in scope \(scope); sibling lists invalidated")
    }

    /// Takes an event just created from this screen so it shows without a round trip: first on Explore, whose order
    /// is the backend's relevance for the caller and where their own new game belongs on top; by start time on a
    /// joined-only list, which stays chronological and takes it only when the caller participates (the host always
    /// does), and on a group's list, which takes only that group's games. Recorded like `replace`, so every other
    /// list reloads on its next appearance; repeated for one id, a no-op.
    func add(_ event: SportEvent) {
        guard !events.contains(where: { $0.id == event.id }) else {
            logger.debug(.cache, "Event \(event.id) already in scope \(scope); add ignored")
            return
        }
        switch scope {
        case .upcoming:
            events.insert(event, at: 0)
        case .joined where event.participates:
            insertByStart(event)
        case .group(let id) where event.group?.id == id:
            insertByStart(event)
        case .joined, .group:
            break
        }
        changes.recordChange()
        freshness.acknowledge(version: changes.version)
        logger.debug(.cache, "Event \(event.id) added to scope \(scope); sibling lists invalidated")
    }

    private func insertByStart(_ event: SportEvent) {
        events.insert(event, at: events.firstIndex { $0.startsAt > event.startsAt } ?? events.endIndex)
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
            freshness.recordSuccess(at: now(), version: version, userID: userID)
            loadedPosition = position?.coarse
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

    /// Only Explore is ordered by distance; My Events is the caller's own games, in start order.
    private var requestPosition: Coordinate? { scope == .upcoming ? userLocation : nil }

    /// Why the user's position makes the content stale, or `nil`: it was loaded without one that is known now, or for
    /// another one than the user's now, so the backend can order it better.
    private var positionReason: String? {
        guard freshness.hasLoaded, let position = requestPosition?.coarse else { return nil }
        guard let loadedPosition else { return "position became known" }
        return loadedPosition == position ? nil : "position changed"
    }

    private var isWaitingToRetry: Bool {
        freshness.isWaitingToRetry(now: now(), version: changes.version, userID: identity.currentUserID)
    }

    /// Why the content must be reloaded, or `nil` while it can be reused: the shared rules first, then the reasons
    /// only Explore has, a position that became known or changed since the load.
    private var stalenessReason: String? {
        freshness.stalenessReason(now: now(), version: changes.version, userID: identity.currentUserID) ?? positionReason
    }
}
