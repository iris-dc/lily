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
    /// The floating "+" on Explore: a menu with New game and New group (either shows the sign-in sheet to a guest).
    static let eventsCreate = "events-create"
    /// Fields and actions of the create sheet.
    static let createTitle = "create-title"
    static let createLocationName = "create-location-name"
    static let createPickOnMap = "create-pick-on-map"
    static let createMap = "create-map"
    static let createMapDone = "create-map-done"
    static let createCapacity = "create-capacity"
    static let createPrice = "create-price"
    static let createSubmit = "create-submit"
    static let createCancel = "create-cancel"
    /// Fields and actions of the email form in the sign-in sheet. The toggle switches sign in / sign up and, on the
    /// confirmation step, reads "Back to sign in".
    static let authEmail = "auth-email"
    static let authPassword = "auth-password"
    static let authConfirmationCode = "auth-confirmation-code"
    static let authSubmit = "auth-submit"
    static let authModeToggle = "auth-mode-toggle"
    static let authResendCode = "auth-resend-code"

    /// One chip per event type in the filter panel, e.g. `filter-type-football`.
    static func filterType(_ type: EventType) -> String {
        "filter-type-\(type.rawValue)"
    }
}
