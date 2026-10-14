import Foundation

/// What Explore's list shows, resolved from the view model's flags in one place rather than by the order of the
/// view's branches. Three rules used to live in that order: the spinner comes before "nothing yet" (a first load is
/// never an empty list), the failed state shows only while nothing is loaded, and a failed refresh keeps the list on
/// screen (or the filtered-out state, which still offers "show everything").
nonisolated enum EventListScreenState: Equatable, Sendable {
    /// The first load is out: a spinner, never "nothing yet".
    case loading
    /// Nothing is loaded and the last load failed.
    case failed
    /// Nothing is loaded and nothing failed: there is nothing here.
    case empty
    /// Events are loaded but the filter hides every one of them.
    case filteredOut
    /// The cards.
    case list

    static func resolve(isInitialLoad: Bool,
                        loadFailed: Bool,
                        hasEvents: Bool,
                        isEverythingFilteredOut: Bool) -> EventListScreenState {
        if isInitialLoad { return .loading }
        guard hasEvents else { return loadFailed ? .failed : .empty }
        return isEverythingFilteredOut ? .filteredOut : .list
    }
}
