import Foundation

/// Identifiers of the display name and "About you" cards and their sheets, and of the Settings screen; a UI test that
/// reads one mirrors the literal by hand.
nonisolated extension AccessibilityIdentifiers {
    /// The "Display name" card on Profile.
    static let profileName = "profile-name"
    static let profileNameField = "profile-name-field"
    static let profileNameSave = "profile-name-save"
    static let profileNameCancel = "profile-name-cancel"
    /// The "About you" card on Profile.
    static let profileAbout = "profile-about"
    static let profileAboutField = "profile-about-field"
    static let profileAboutSave = "profile-about-save"
    static let profileAboutCancel = "profile-about-cancel"
    /// The Settings link row on the profile root, and the Settings screen's own rows.
    static let profileSettings = "profile-settings"
    static let settingsSignOut = "settings-sign-out"
    static let settingsPrivacy = "settings-privacy"
    static let settingsTerms = "settings-terms"
}
