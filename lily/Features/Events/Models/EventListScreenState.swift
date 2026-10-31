import Foundation

/// What Explore's list shows, resolved from the view model's flags in one place. The cards whenever the list holds
/// any, the last answer kept on the device included while the first load is still out; a first load over nothing shows
/// the spinner, never "nothing yet"; the failed state shows only while nothing is loaded, so a failed refresh keeps the
/// list on screen (or the filtered-out state, which still offers "show everything"). Content that is not the answer for
/// the user's position and that the filter hides entirely shows the spinner, not "nothing matches": the answer for the
/// position is on its way and may hold other events, or none.
nonisolated enum EventListScreenState: Equatable, Sendable {
    /// The first load is out and nothing is held: a spinner, never "nothing yet".
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
                        isEverythingFilteredOut: Bool,
                        awaitsAnswerForPosition: Bool = false) -> EventListScreenState {
        guard hasEvents else {
            if isInitialLoad { return .loading }
            return loadFailed ? .failed : .empty
        }
        guard isEverythingFilteredOut else { return .list }
        return awaitsAnswerForPosition ? .loading : .filteredOut
    }
}
