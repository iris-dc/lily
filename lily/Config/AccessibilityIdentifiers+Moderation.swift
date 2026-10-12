import Foundation

/// Identifiers of the terms sheet and the report sheet; mirrored by hand in `lilyUITests` like the rest. The report
/// sheet's reason rows carry none: an inline `Picker`'s rows are cells XCUITest finds by label.
nonisolated extension AccessibilityIdentifiers {
    /// The terms sheet's two ways out: agreeing, or signing out without agreeing.
    static let termsAccept = "terms-accept"
    static let termsSignOut = "terms-sign-out"
    static let reportComment = "report-comment"
    static let reportSubmit = "report-submit"
    static let reportDone = "report-done"
}
