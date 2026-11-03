import Foundation

/// Identifiers of the contact form; a UI test that reads one mirrors the literal by hand. The kind picker is segmented, so
/// its segments are plain buttons XCUITest finds by label.
nonisolated extension AccessibilityIdentifiers {
    /// The "Contact & feedback" row on Profile.
    static let profileFeedback = "profile-feedback"
    static let feedbackMessage = "feedback-message"
    static let feedbackEmail = "feedback-email"
    static let feedbackSubmit = "feedback-submit"
    static let feedbackDone = "feedback-done"
}
