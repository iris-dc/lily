import Foundation

/// The filter as the panel drives it, the list/map switch, and the interactions both report. Apart from the loading
/// logic so each file stays readable; every stored property lives in the main type.
extension EventListViewModel {
    /// Events were loaded but the filter hides all of them, so the screen offers to clear it instead of saying "nothing yet".
    var isEverythingFilteredOut: Bool { !events.isEmpty && visibleEvents.isEmpty }

    /// The currency the panel's price cap is in: the user's, so its symbol follows the Profile choice.
    var priceCurrencyCode: String { currencyCode() }

    func toggleType(_ type: EventType) {
        updateFilter { $0.toggle(type) }
    }

    /// Back to the defaults (which still limit distance).
    func clearFilter() {
        updateFilter { $0.clear() }
    }

    /// Lifts every criterion, the default radius included: the way out when the defaults alone hide every event.
    /// Reached from the empty state rather than the panel, so it reports itself.
    func showEverything() {
        updateFilter { $0 = .everything }
        recordFilterApplied()
    }

    /// Distance from the user, formatted for the current locale, or `nil` while location is unknown.
    func distanceText(for event: SportEvent) -> String? {
        event.distance(from: userLocation)?.roadText
    }

    /// Remembers what the panel opened on, so closing it reports one `filter_applied` only when something changed.
    func filterPanelOpened() {
        filterWhenPanelOpened = filter
    }

    func filterPanelClosed() {
        defer { filterWhenPanelOpened = nil }
        guard let opened = filterWhenPanelOpened, opened != filter else { return }
        recordFilterApplied()
    }

    func presentationChanged(to presentation: EventsPresentation) {
        recorder.record(.presentationChanged(presentation, at: now()))
    }

    private func recordFilterApplied() {
        recorder.record(.filterApplied(filter, at: now()))
    }
}
