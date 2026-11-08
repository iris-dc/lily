import SwiftUI

/// The terms of use read in place: pushed from Settings' terms row (owner decision 2026-11-08 — agreement is by use,
/// so the terms are reading content like the privacy policy, with no version stamp and nothing to accept). Like
/// `SettingsScreen`, the language is an input, so the push re-renders in place on a pick instead of popping.
struct TermsScreen: View {
    /// The language the copy is in; a change re-runs this body and every section's text with it.
    let language: AppLanguage

    var body: some View {
        LegalScreen(title: AppBranding.Moderation.termsLink,
                    identifier: AccessibilityIdentifiers.settingsTermsOfUse,
                    sections: AppBranding.Terms.sections)
    }
}

#Preview {
    NavigationStack {
        TermsScreen(language: .english)
    }
}
