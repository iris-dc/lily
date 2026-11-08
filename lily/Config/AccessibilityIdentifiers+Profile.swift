import Foundation

/// Identifiers of the corner profile button and its sheet, the display name and "About you" cards and their sheets,
/// and the Settings screen; a UI test that reads one mirrors the literal by hand.
nonisolated extension AccessibilityIdentifiers {
    /// The corner profile button on every tab root, and the profile sheet it presents (on the sheet's root container).
    static let profileCorner = "profile-corner"
    static let profileSheet = "profile-sheet"
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
    /// The pushed privacy policy screen (its content container; the sections are plain text).
    static let settingsPrivacyPolicy = "settings-privacy-policy"
    /// The pushed terms-of-use screen (its content container; the sections are plain text).
    static let settingsTermsOfUse = "settings-terms-of-use"
    /// Close on the legal sheets the sign-up footnote presents (the same screens Settings pushes).
    static let legalClose = "legal-close"
    /// The delete-account flow: the Settings row and the sheet's three actions.
    static let settingsDeleteAccount = "settings-delete-account"
    static let deleteAccountConfirm = "delete-account-confirm"
    static let deleteAccountCancel = "delete-account-cancel"
    static let deleteAccountAcknowledge = "delete-account-acknowledge"
}
