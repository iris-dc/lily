import Foundation

/// Identifiers of the creation wizard; a UI test that reads one mirrors the literal by hand.
nonisolated extension AccessibilityIdentifiers {
    /// The type pages' choice cards (event, group and tournament), one per known event type, by wire name
    /// ("create-type-table_tennis").
    static func createEventType(_ wireName: String) -> String { "create-type-\(wireName)" }

    /// The type pages' search field, filtering the type grid by localized name as you type.
    static let createTypeSearch = "create-type-search"

    /// The group type page's "Any type" card; the per-type cards reuse `createEventType(_:)`.
    static let createTypeAny = "create-type-any"

    /// The visibility pages' choice cards: a group's, and a standalone tournament's who-may-join.
    static func createVisibility(_ visibility: GroupVisibility) -> String { "create-visibility-\(visibility.rawValue)" }

    /// The tournament format page's choice cards, by wire name ("create-format-round_robin").
    static func createFormat(_ wireName: String) -> String { "create-format-\(wireName)" }
    /// The bottom bar's primary button on every step but the last (the final step keeps `createSubmit`).
    static let createNext = "create-next"
    /// A step page's content container, a container element so children keep their own identifiers.
    static let createStep = "create-step"
}
