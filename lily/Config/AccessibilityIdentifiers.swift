import Foundation

/// Accessibility identifiers the app puts on controls for the UI tests to query. A UI test that reads one mirrors the
/// literal by hand (as it does for `AppConfig.LaunchArguments`), so a rename here must be repeated there or the test
/// stops finding the control.
nonisolated enum AccessibilityIdentifiers {
    /// Segmented list/map picker in the Explore toolbar.
    static let eventsPresentation = "events-presentation"
    /// Toolbar button that opens the filter sheet.
    static let eventsFilter = "events-filter"
    /// The "Any type" chip in the filter sheet; the per-type chips come from `filterType(_:)`.
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

    /// One place suggestion under the create form's name field, by its position.
    static func createPlaceSuggestion(_ index: Int) -> String {
        "create-place-suggestion-\(index)"
    }
    static let createMap = "create-map"
    static let createMapDone = "create-map-done"
    static let createCapacity = "create-capacity"
    static let createPlayerLimit = "create-player-limit"
    static let createPrice = "create-price"
    static let createSubmit = "create-submit"
    static let createCancel = "create-cancel"
    /// The Edit button in the event detail's toolbar, shown to the host; the sheet reuses the create identifiers.
    static let eventEdit = "event-edit"
    /// The non-interactive map on the event detail.
    static let eventDetailMap = "event-detail-map"
    /// Fields and actions of the email form in the sign-in sheet. The toggle switches sign in / sign up and, on the
    /// confirmation step, reads "Back to sign in".
    static let authEmail = "auth-email"
    static let authPassword = "auth-password"
    static let authConfirmationCode = "auth-confirmation-code"
    static let authSubmit = "auth-submit"
    static let authModeToggle = "auth-mode-toggle"
    static let authResendCode = "auth-resend-code"
    static let signInClose = "sign-in-close"
    static let authBack = "auth-back"
    /// The agreement footnote under the sign-up form; its two link runs open the in-app legal sheets.
    static let authAgreement = "auth-agreement"

    /// One chip per event type in the filter sheet, e.g. `filter-type-football`.
    static func filterType(_ type: EventType) -> String {
        "filter-type-\(type.wireName)"
    }
}
