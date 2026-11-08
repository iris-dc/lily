import SwiftUI

/// The privacy policy read in place: pushed from Settings' privacy row (owner correction 2026-11-08 — no browser
/// round trip), every section of `AppBranding.Privacy` rendered by `LegalScreen`. The served page's date line and
/// "also available at" footer stay on the page alone (owner decision 2026-11-08). Like `SettingsScreen`, the
/// language is an input, so the push re-renders in place on a pick instead of popping.
struct PrivacyPolicyScreen: View {
    /// The language the copy is in; a change re-runs this body and every section's text with it.
    let language: AppLanguage

    var body: some View {
        LegalScreen(title: AppBranding.Moderation.privacyLink,
                    identifier: AccessibilityIdentifiers.settingsPrivacyPolicy,
                    sections: AppBranding.Privacy.sections)
    }
}

#Preview {
    NavigationStack {
        PrivacyPolicyScreen(language: .english)
    }
}
