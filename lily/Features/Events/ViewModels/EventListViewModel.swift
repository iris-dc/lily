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
    /// True from a failed load until the next successful one, so the screen can say so instead of "nothing yet".
    private(set) var loadFailed = false
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
    private let changes: EventChangeTracker
    private let errorCenter: ErrorCenter
    private var lastLoadedAt: Date?
    /// The load that failed last: when, and what it asked for. Cleared by a success. Not retried before
    /// `AppConfig.Events.retryAfterFailure` unless something that changes the answer happened since.
    private var failedAttempt: FailedAttempt?

    private struct FailedAttempt {
        let at: Date
        let version: Int
        let userID: String?
    }
    /// `changes.version` the current content reflects; a different value means another screen changed an event.
    private var loadedVersion: Int?
    /// Who the current content was loaded for. `isJoined` is the server's answer for that caller, so a sign-in or
    /// sign-out makes the content stale even though nothing else changed.
    private var loadedUserID: String?
    /// Whether the current content was asked for with the user's position, which lets the backend order it by distance.
    private var loadedWithPosition = false

    init(scope: EventScope,
         repository: any EventRepository,
         identity: any IdentityProvider,
         locationService: any LocationService,
         changes: EventChangeTracker,
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
    var isInitialLoad: Bool { isLoading && lastLoadedAt == nil && !loadFailed }

    /// Distance is judged from the user's position; while that is unknown the distance criterion is skipped.
    var visibleEvents: [SportEvent] { events.filter { filter.matches($0, from: userLocation) } }

    /// The one way views change the filter, so every change is logged and the filter stays `private(set)`.
    func updateFilter(_ change: (inout EventFilter) -> Void) {
        change(&filter)
        logger.debug(.events, "Filter changed; active: \(filter.isActive), visible: \(visibleEvents.count) of \(events.count)")
    }

    /// Loads once per `AppConfig.Events.listStaleAfter`, or sooner when another screen changed an event meanwhile,
    /// the caller changed (sign-in or sign-out; `isJoined` is per caller) or the position became known after an
    /// Explore load without one (the backend orders by distance), so a tab that reappears reuses what it already has.
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
    /// user's position when known; one that arrived while the request was out earns one reload right away, so the
    /// backend's relevance order replaces the plain time order without waiting for the next appearance.
    func load() async {
        guard !isLoading else { return }
        isLoading = true
        let position = requestPosition
        let succeeded = await performLoad(near: position)
        isLoading = false
        if succeeded, position == nil, positionBecameKnown {
            logger.debug(.cache, "Events for scope \(scope): position became known while loading; reloading")
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
        loadedVersion = changes.version
        logger.debug(.cache, "Event \(event.id) replaced in scope \(scope); sibling lists invalidated")
    }

    /// Takes an event just created from this screen so it shows without a round trip: first on Explore, whose order
    /// is the backend's relevance for the caller and where their own new game belongs on top; by start time on a
    /// joined-only list, which stays chronological and takes it only when the caller participates (the host always
    /// does). Recorded like `replace`, so every other list reloads on its next appearance; repeated for one id, a no-op.
    func add(_ event: SportEvent) {
        guard !events.contains(where: { $0.id == event.id }) else {
            logger.debug(.cache, "Event \(event.id) already in scope \(scope); add ignored")
            return
        }
        switch scope {
        case .upcoming:
            events.insert(event, at: 0)
        case .joined where event.participates:
            events.insert(event, at: events.firstIndex { $0.startsAt > event.startsAt } ?? events.endIndex)
        case .joined:
            break
        }
        changes.recordChange()
        loadedVersion = changes.version
        logger.debug(.cache, "Event \(event.id) added to scope \(scope); sibling lists invalidated")
    }

    /// Location is optional context: failures leave `userLocation` nil and the UI simply omits distances. A position
    /// that arrives after an Explore load without one makes that content stale (see `loadIfStale`); a load in flight
    /// notices the position itself when it finishes.
    func loadUserLocation() async {
        guard userLocation == nil else { return }
        userLocation = await locationService.currentLocation()
        logger.info(.location, userLocation == nil ? "No user location" : "User location available")
        if positionBecameKnown, !isLoading {
            await loadIfStale()
        }
    }

    /// For moments when permission may have changed (the app came back to the foreground): a remembered "no fix"
    /// is dropped first, so the retry really asks CoreLocation instead of hitting the cache.
    func retryUserLocationIfMissing() async {
        guard userLocation == nil else { return }
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
            lastLoadedAt = now()
            failedAttempt = nil
            loadedVersion = version
            loadedUserID = userID
            loadedWithPosition = position != nil
            loadFailed = false
            logger.info(.events, "Loaded \(events.count) events for scope \(scope); with position: \(position != nil)")
            return true
        } catch {
            guard !AppError.isCancellation(error) else {
                logger.debug(.events, "Loading events cancelled for scope \(scope)")
                return false
            }
            failedAttempt = FailedAttempt(at: now(), version: version, userID: userID)
            loadFailed = true
            logger.error(.events, "Loading events failed for scope \(scope): \(error)")
            errorCenter.report(error)
            return false
        }
    }

    /// Only Explore is ordered by distance; My Events is the caller's own games, in start order.
    private var requestPosition: Coordinate? { scope == .upcoming ? userLocation : nil }

    /// Content loaded without a position while one is known now: the backend can order it better.
    private var positionBecameKnown: Bool {
        lastLoadedAt != nil && !loadedWithPosition && requestPosition != nil
    }

    /// True from a failed load until `AppConfig.Events.retryAfterFailure` has passed, unless a change made elsewhere
    /// or a change of caller since then means the answer is different anyway.
    private var isWaitingToRetry: Bool {
        guard loadFailed, let failedAttempt else { return false }
        guard failedAttempt.version == changes.version, failedAttempt.userID == identity.currentUserID else { return false }
        return now().timeIntervalSince(failedAttempt.at) < AppConfig.Events.retryAfterFailure
    }

    /// Why the content must be reloaded, or `nil` while it can be reused.
    private var stalenessReason: String? {
        guard let lastLoadedAt else { return loadFailed ? "retry after failure" : "never loaded" }
        if loadedVersion != changes.version { return "changed elsewhere" }
        if loadedUserID != identity.currentUserID { return "caller changed" }
        if positionBecameKnown { return "position became known" }
        if loadFailed { return "retry after failure" }
        if now().timeIntervalSince(lastLoadedAt) >= AppConfig.Events.listStaleAfter { return "older than TTL" }
        return nil
    }
}
