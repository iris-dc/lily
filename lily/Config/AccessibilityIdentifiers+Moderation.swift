import Foundation

/// Identifiers of the report sheet; a UI test that reads one mirrors the literal by hand. The report sheet's reason
/// rows carry none: an inline `Picker`'s rows are cells XCUITest finds by label.
nonisolated extension AccessibilityIdentifiers {
    static let reportComment = "report-comment"
    static let reportSubmit = "report-submit"
    static let reportDone = "report-done"
}
