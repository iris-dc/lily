import Foundation

/// Identifiers of the report sheet; mirrored by hand in `lilyUITests` like the rest. The reason rows carry none: an
/// inline `Picker`'s rows are cells XCUITest finds by label.
nonisolated extension AccessibilityIdentifiers {
    static let reportComment = "report-comment"
    static let reportSubmit = "report-submit"
    static let reportDone = "report-done"
}
