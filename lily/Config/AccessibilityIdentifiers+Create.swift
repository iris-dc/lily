import Foundation

/// Identifiers of the creation wizard; a UI test that reads one mirrors the literal by hand.
nonisolated extension AccessibilityIdentifiers {
    /// The kind page's choice cards, one per offered kind.
    static let createKindEvent = "create-kind-event"
    static let createKindGroup = "create-kind-group"
    static let createKindTournament = "create-kind-tournament"
    /// The bottom bar's primary button on every step but the last (the final step keeps `createSubmit`).
    static let createNext = "create-next"
    /// A step page's content container, a container element so children keep their own identifiers.
    static let createStep = "create-step"
}
