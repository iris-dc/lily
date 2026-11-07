import SwiftUI

/// The signed-in settings, pushed from the profile root's link row: the language and currency cards, the contact card,
/// the two legal links, Sign out and Delete account at the end. Guests never reach it: their three rows stay inline on
/// the profile root. Like `ProfileView`, the screen re-renders in place when the language changes (`language` is an input for that
/// alone), so a pick made here never pops the push.
struct SettingsScreen: View {
    let dependencies: AppDependencies
    /// The language the copy is in; a change re-runs this body and, through it, every row's.
    let language: AppLanguage
    @State private var isFeedbackPresented = false
    @State private var isDeletePresented = false
    @Environment(\.openURL) private var openURL

    var body: some View {
        ContentScreen {
            // Scrolls only once the rows outgrow the screen (an accessibility size); at the default size it sits still.
            ScrollView {
                VStack(spacing: DesignTokens.Spacing.xl) {
                    LanguageRow(language: dependencies.language)
                    CurrencyRow(currency: dependencies.currency)
                    // Its only input is a closure, which SwiftUI does not count as a change, so it would keep the old copy.
                    FeedbackRow { isFeedbackPresented = true }
                        .id(language)
                    legalRow(title: AppBranding.Moderation.privacyLink,
                             subtitle: AppBranding.Settings.privacySubtitle,
                             systemImage: DesignTokens.Symbols.privacy,
                             identifier: AccessibilityIdentifiers.settingsPrivacy,
                             destination: AppConfig.Moderation.privacyURL)
                    legalRow(title: AppBranding.Moderation.termsLink,
                             subtitle: AppBranding.Settings.termsSubtitle,
                             systemImage: DesignTokens.Symbols.terms,
                             identifier: AccessibilityIdentifiers.settingsTerms,
                             destination: AppConfig.Moderation.termsURL)
                    signOutButton
                    deleteAccountButton
                }
                .padding(.horizontal, DesignTokens.Layout.screenMargin)
                .padding(.vertical, DesignTokens.Spacing.xl)
                .readableColumn()
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .navigationTitle(AppBranding.Settings.title)
        .sheet(isPresented: $isFeedbackPresented) {
            FeedbackSheet(viewModel: dependencies.makeFeedbackViewModel(), errorCenter: dependencies.errorCenter)
        }
        .sheet(isPresented: $isDeletePresented) {
            DeleteAccountSheet(viewModel: dependencies.makeDeleteAccountViewModel(), errorCenter: dependencies.errorCenter)
        }
    }

    /// A legal page opened in the browser, as the terms sheet's links do; Laurel serves it beside the API.
    private func legalRow(title: String,
                          subtitle: String,
                          systemImage: String,
                          identifier: String,
                          destination: URL) -> some View {
        SettingsLinkRow(title: title,
                        subtitle: subtitle,
                        systemImage: systemImage,
                        identifier: identifier) { openURL(destination) }
    }

    /// Moved off the profile header: a full-width text action at the list's end, the shape the terms sheet's Sign out takes.
    private var signOutButton: some View {
        Button {
            Task { await dependencies.sessionController.signOut() }
        } label: {
            Text(AppBranding.signOutAction)
                .frame(maxWidth: .infinity)
        }
        .lilyTextButton()
        .accessibilityIdentifier(AccessibilityIdentifiers.settingsSignOut)
    }

    /// The destructive end of the list (the relocation contract): the flow itself is `DeleteAccountSheet`; red, so it
    /// never reads as another preference.
    private var deleteAccountButton: some View {
        Button(role: .destructive) {
            isDeletePresented = true
        } label: {
            Text(AppBranding.DeleteAccount.title)
                .frame(maxWidth: .infinity)
        }
        .lilyTextButton(color: .red)
        .accessibilityIdentifier(AccessibilityIdentifiers.settingsDeleteAccount)
    }
}

#Preview {
    let dependencies = AppDependencies.makeMock()
    NavigationStack {
        SettingsScreen(dependencies: dependencies, language: dependencies.language.language)
    }
}
