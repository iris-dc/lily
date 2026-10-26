import SwiftUI

/// The caller's profile or the guest prompt, the language, the currency and the contact card. The screen re-renders in
/// place when the language changes (`language` is an input for that alone; every row reads its copy afresh, or is given
/// the language as its identity when nothing else about it changes), rather than being rebuilt like the other tabs: a
/// rebuilt tree crossfaded over the pick and dimmed the screen for a frame.
struct ProfileView: View {
    let dependencies: AppDependencies
    /// The language the copy is in; a change re-runs this body and, through it, every row's.
    let language: AppLanguage
    @State private var isSignInPresented = false
    @State private var isFeedbackPresented = false

    private var session: SessionController { dependencies.sessionController }

    var body: some View {
        NavigationStack {
            ContentScreen {
                VStack(spacing: DesignTokens.Spacing.xl) {
                    if let user = session.state.user {
                        signedIn(user)
                    } else {
                        guest
                    }
                    LanguageRow(language: dependencies.language)
                    CurrencyRow(currency: dependencies.currency)
                    // Its only input is a closure, which SwiftUI does not count as a change, so it kept the old language.
                    FeedbackRow(action: openFeedback)
                        .id(language)
                    Spacer()
                }
                .padding(.horizontal, DesignTokens.Layout.screenMargin)
                .padding(.vertical, DesignTokens.Spacing.xl)
                .readableColumn()
            }
            .navigationTitle(AppBranding.profileTitle)
        }
        .sheet(isPresented: $isSignInPresented) {
            SignInSheet(session: session, errorCenter: dependencies.errorCenter)
        }
        .sheet(isPresented: $isFeedbackPresented) {
            FeedbackSheet(viewModel: dependencies.makeFeedbackViewModel(), errorCenter: dependencies.errorCenter)
        }
    }

    /// A guest signs in first, as for every write: the backend takes a message from an account only.
    private func openFeedback() {
        if session.state.isSignedIn {
            isFeedbackPresented = true
        } else {
            dependencies.logger.info(.auth, "Guest asked to send feedback from Profile; showing sign-in")
            isSignInPresented = true
        }
    }

    private func signedIn(_ user: AuthUser) -> some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            AvatarCircle(initials: user.initials)
            VStack(spacing: DesignTokens.Spacing.xs) {
                Text(user.displayName).font(LilyTheme.Fonts.cardTitle)
                if let email = user.email {
                    Text(email).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Button(AppBranding.signOutAction) { Task { await session.signOut() } }
                .lilyGlassButton()
        }
    }

    /// Laid straight on the screen, not in a card, so the heading shares the navigation title's leading edge.
    private var guest: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text(AppBranding.guestProfileTitle).font(LilyTheme.Fonts.cardTitle)
            Text(AppBranding.guestProfileMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button(AppBranding.signInAction) { isSignInPresented = true }
                .lilyProminentButton()
                .padding(.top, DesignTokens.Spacing.sm)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
