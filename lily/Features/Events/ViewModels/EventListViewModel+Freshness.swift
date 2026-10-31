import Foundation

/// What the content's freshness says about the screen: the states a view reads, and the staleness rules `loadIfStale`
/// applies. Apart from the loading logic so each file stays readable; every stored property lives in the main type.
extension EventListViewModel {
    /// Nothing to show yet: no snapshot and no answer, from the first frame through the location wait and the first load,
    /// so the screen spins rather than saying "nothing yet" before the list was asked. Later loads keep the current
    /// content (and its refresh spinner) on screen.
    var isInitialLoad: Bool { !startedFromSnapshot && !freshness.hasLoaded && !loadFailed }

    /// What a segment drawing this list shows now.
    var listState: ListState { ListState(isInitialLoad: isInitialLoad, isEmpty: visibleEvents.isEmpty, loadFailed: loadFailed) }

    /// True from a failed load until the next successful one, so the screen can say so instead of "nothing yet".
    var loadFailed: Bool { freshness.loadFailed }

    /// An answer landed at least once since the last reset; `loadFailed` is the other way a load ends.
    var hasLoaded: Bool { freshness.hasLoaded }

    /// Only Explore is ordered by distance; Home is the caller's own games, in start order.
    var requestPosition: Coordinate? { scope == .upcoming ? userLocation : nil }

    /// Why the user's position makes Explore content stale (`ContentFreshness.positionReason`); Home sends none.
    var positionReason: String? { freshness.positionReason(for: requestPosition) }

    var isWaitingToRetry: Bool {
        freshness.isWaitingToRetry(now: now(), version: changes.version, userID: identity.currentUserID)
    }

    /// Why the content must be reloaded, or `nil` while it can be reused: the shared rules first, then the position
    /// only Explore sends.
    var stalenessReason: String? {
        freshness.stalenessReason(now: now(),
                                  version: changes.version,
                                  userID: identity.currentUserID,
                                  position: requestPosition)
    }
}
