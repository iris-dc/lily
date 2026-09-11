import Foundation
import Observation

/// Drives every list and map of events (explore, my events). Scope decides which slice is loaded.
@Observable
final class EventListViewModel {
    private(set) var events: [SportEvent] = []
    /// Narrows `events` to `visibleEvents` on device; the map and the list read the same slice.
    private(set) var filter: EventFilter
    private(set) var isLoading = false
    /// True from a failed load until the next successful one, so the screen can say so instead of "nothing yet".
    private(set) var loadFailed = false
    private(set) var userLocation: Coordinate?

    private let scope: EventScope
    private let repository: any EventRepository
    private let locationService: any LocationService
    private let changes: EventChangeTracker
    private let errorCenter: ErrorCenter
    private let logger: any Logging
    private let now: () -> Date
    private var lastLoadedAt: Date?
    /// `changes.version` the current content reflects; a different value means another screen changed an event.
    private var loadedVersion: Int?

    init(scope: EventScope,
         repository: any EventRepository,
         locationService: any LocationService,
         changes: EventChangeTracker,
         errorCenter: ErrorCenter,
         logger: any Logging,
         now: @escaping () -> Date = { .now },
         initialFilter: EventFilter = EventFilter()) {
        self.filter = initialFilter
        self.scope = scope
        self.repository = repository
        self.locationService = locationService
        self.changes = changes
        self.errorCenter = errorCenter
        self.logger = logger
        self.now = now
    }

    /// The very first load, before any result exists. Later loads keep the current content (and its refresh spinner) on screen.
    var isInitialLoad: Bool { isLoading && lastLoadedAt == nil && !loadFailed }

    /// Distance is judged from the user's position; while that is unknown the distance criterion is skipped.
    var visibleEvents: [SportEvent] { events.filter { filter.matches($0, from: userLocation) } }

    /// Events were loaded but the filter hides all of them, so the screen offers to clear it instead of saying "nothing yet".
    var isEverythingFilteredOut: Bool { !events.isEmpty && visibleEvents.isEmpty }

    /// Types in the loaded events, plus any selected type a reload has since dropped so it can still be deselected,
    /// in the canonical `EventType` order.
    var availableTypes: [EventType] {
        let present = Set(events.map(\.type))
        return EventType.allCases.filter { present.contains($0) || filter.includes($0) }
    }

    func toggleType(_ type: EventType) {
        updateFilter { $0.toggle(type) }
    }

    /// The one way views change the filter, so every change is logged and the filter stays `private(set)`.
    func updateFilter(_ change: (inout EventFilter) -> Void) {
        change(&filter)
        logger.debug(.events, "Filter changed; active: \(filter.isActive), visible: \(visibleEvents.count) of \(events.count)")
    }

    /// Back to the defaults (which still limit distance).
    func clearFilter() {
        updateFilter { $0.clear() }
    }

    /// Lifts every criterion, the default radius included: the way out when the defaults alone hide every event.
    func showEverything() {
        updateFilter { $0 = .everything }
    }

    /// Distance from the user, formatted for the current locale, or `nil` while location is unknown.
    func distanceText(for event: SportEvent) -> String? {
        event.distance(from: userLocation)?.roadText
    }

    /// Loads once per `AppConfig.Events.listStaleAfter`, or sooner when another screen changed an event meanwhile,
    /// so a tab that reappears reuses what it already has.
    func loadIfStale() async {
        guard isStale else {
            logger.debug(.cache, "Events for scope \(scope) are fresh; skipping reload")
            return
        }
        await load()
    }

    /// Always asks the repository (pull-to-refresh). A call made while one is in flight is dropped.
    func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        // Taken before the request: a change landing mid-flight may be missing from the answer, and must reload.
        let version = changes.version
        do {
            events = try await repository.events(in: scope)
            lastLoadedAt = now()
            loadedVersion = version
            loadFailed = false
            logger.info(.events, "Loaded \(events.count) events for scope \(scope)")
        } catch {
            guard !AppError.isCancellation(error) else {
                logger.debug(.events, "Loading events cancelled for scope \(scope)")
                return
            }
            loadFailed = true
            logger.error(.events, "Loading events failed for scope \(scope): \(error)")
            errorCenter.report(AppError.eventsUnavailable)
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
    }

    /// Location is optional context: failures leave `userLocation` nil and the UI simply omits distances.
    func loadUserLocation() async {
        guard userLocation == nil else { return }
        userLocation = await locationService.currentLocation()
        logger.info(.location, userLocation == nil ? "No user location" : "User location available")
    }

    /// For moments when permission may have changed (the app came back to the foreground): a remembered "no fix"
    /// is dropped first, so the retry really asks CoreLocation instead of hitting the cache.
    func retryUserLocationIfMissing() async {
        guard userLocation == nil else { return }
        locationService.forgetMissingFix()
        await loadUserLocation()
    }

    private var isStale: Bool {
        guard let lastLoadedAt, loadedVersion == changes.version else { return true }
        return now().timeIntervalSince(lastLoadedAt) >= AppConfig.Events.listStaleAfter
    }
}
