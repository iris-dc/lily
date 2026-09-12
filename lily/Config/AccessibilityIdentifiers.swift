import Foundation

/// Accessibility identifiers the app puts on controls for the UI tests to query. `lilyUITests` mirrors these literals
/// (as it does for `AppConfig.LaunchArguments`), so a rename here must be repeated there or the smoke tests stop
/// finding the control.
nonisolated enum AccessibilityIdentifiers {
    /// Segmented list/map picker in the Explore toolbar.
    static let eventsPresentation = "events-presentation"
    /// Toolbar button that drops the filter panel down.
    static let eventsFilter = "events-filter"
    /// The "Any type" chip in the filter panel; the per-type chips come from `filterType(_:)`.
    static let filterTypeAny = "filter-type-any"
    static let filterFreeOnly = "filter-free-only"
    static let filterMaxPrice = "filter-max-price"
    static let eventsMap = "events-map"
    /// Preview card shown above the map for the selected pin.
    static let mapSelectedCard = "map-selected-card"

    /// One chip per event type in the filter panel, e.g. `filter-type-football`.
    static func filterType(_ type: EventType) -> String {
        "filter-type-\(type.rawValue)"
    }
}
