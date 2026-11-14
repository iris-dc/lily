import Foundation

/// The segmented Home's identifiers; UI tests mirror the literals by hand (the test target cannot import the app).
nonisolated extension AccessibilityIdentifiers {
    /// The segmented Events | Tournaments | Groups picker under the Home title.
    static let homeSegment = "home-segment"
    /// The full-width create button under the picker, seeding the wizard with the selected segment's kind.
    static let homeCreate = "home-create"
}
