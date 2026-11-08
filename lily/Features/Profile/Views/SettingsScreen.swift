import SwiftUI

/// The signed-in settings, pushed from the profile root's link row: the language and currency cards, the contact card,
/// the privacy policy (pushed in place, owner correction 2026-11-08), the terms link, Sign out and Delete account at
/// the end. Guests never reach it: their three rows stay inline on the profile root. Like `ProfileView`, the screen
/// re-renders in place when the language changes (`language` is an input for that alone), so a pick made here never
/// pops the push.
struct SettingsScreen: View {
    let dependencies: AppDependencies
    /// The language the copy is in; a change re-runs this body and, through it, every row's.
    let language: AppLanguage
    @State private var isFeedbackPresented = false
    @State private var isDeletePresented = false
    @State private var isPrivacyPresented = false
    @Environment(\.openURL) private var openURL
    @Environment(\.layoutMode) private var layoutMode

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
                    privacyRow
                    termsRow
                    accountActions
                }
                .padding(.horizontal, DesignTokens.Layout.screenMargin)
                .padding(.vertical, DesignTokens.Spacing.xl)
                .readableColumn()
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .navigationTitle(AppBranding.Settings.title)
        .navigationDestination(isPresented: $isPrivacyPresented) {
            PrivacyPolicyScreen(language: language)
        }
        .sheet(isPresented: $isFeedbackPresented) {
            FeedbackSheet(viewModel: dependencies.makeFeedbackViewModel(), errorCenter: dependencies.errorCenter)
        }
        .sheet(isPresented: $isDeletePresented) {
            DeleteAccountSheet(viewModel: dependencies.makeDeleteAccountViewModel(), errorCenter: dependencies.errorCenter)
        }
    }

    /// The policy itself, read in place (owner correction 2026-11-08): no browser round trip for reading it.
    private var privacyRow: some View {
        SettingsLinkRow(title: AppBranding.Moderation.privacyLink,
                        subtitle: AppBranding.Settings.privacySubtitle,
                        systemImage: DesignTokens.Symbols.privacy,
                        identifier: AccessibilityIdentifiers.settingsPrivacy) { isPrivacyPresented = true }
    }

    /// The terms stay a browser link (the owner asked only about privacy); Laurel serves the page beside the API.
    private var termsRow: some View {
        SettingsLinkRow(title: AppBranding.Moderation.termsLink,
                        subtitle: AppBranding.Settings.termsSubtitle,
                        systemImage: DesignTokens.Symbols.terms,
                        identifier: AccessibilityIdentifiers.settingsTerms) { openURL(AppConfig.Moderation.termsURL) }
    }

    /// Sign out and Delete account read as one account-actions group: flush, since each label already carries the
    /// 44 pt hit area, whose slack keeps the labels apart; the list's own spacing above marks the break from the rows.
    /// On a regular layout the iPad's fixed-height form sheet folds right across the red label, cutting it mid-glyph;
    /// the clearance drops the group below the fold, so the fold lands on blank slack and a scroll reveals the pair.
    private var accountActions: some View {
        VStack(spacing: DesignTokens.Spacing.accountActions) {
            signOutButton
            deleteAccountButton
        }
        .padding(.top, layoutMode.isRegular ? DesignTokens.Spacing.accountActionsFoldClearance : 0)
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
