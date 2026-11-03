import SwiftUI

/// The caller's profile (the name other players see, with the card that edits it) or the guest prompt, the language,
/// the currency and the contact card. The screen re-renders in place when the language changes (`language` is an
/// input for that alone; every row reads its copy afresh, or is given the language as its identity when nothing else
/// about it changes), rather than being rebuilt like the other tabs, whose rebuild would crossfade over the pick made
/// here.
struct ProfileView: View {
    let dependencies: AppDependencies
    /// The language the copy is in; a change re-runs this body and, through it, every row's.
    let language: AppLanguage
    @State private var isSignInPresented = false
    @State private var isNamePresented = false
    @State private var isFeedbackPresented = false

    private var session: SessionController { dependencies.sessionController }
    private var profile: ProfileStore { dependencies.profile }

    var body: some View {
        NavigationStack {
            ContentScreen {
                VStack(spacing: DesignTokens.Spacing.xl) {
                    if let user = session.state.user {
                        signedIn(user)
                        DisplayNameRow(store: profile) { isNamePresented = true }
                            .id(language)
                    } else {
                        guest
                    }
                    LanguageRow(language: dependencies.language)
                    CurrencyRow(currency: dependencies.currency)
                    // Its only input is a closure, which SwiftUI does not count as a change, so it would keep the old copy.
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
        .sheet(isPresented: $isNamePresented) {
            DisplayNameSheet(viewModel: dependencies.makeDisplayNameViewModel(), errorCenter: dependencies.errorCenter)
        }
        .sheet(isPresented: $isFeedbackPresented) {
            FeedbackSheet(viewModel: dependencies.makeFeedbackViewModel(), errorCenter: dependencies.errorCenter)
        }
        // Lazily, once per session: nothing else needs the name, so a user who never opens Profile costs no request.
        .task(id: session.state.user?.id) { await profile.loadIfNeeded() }
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

    /// The name is the backend's, or the last one shown while the load runs: a glyph and a spinner stand in only for a
    /// first load, nothing when it failed (the card below still renames); the glyph crossfades into the initials.
    private func signedIn(_ user: AuthUser) -> some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            AvatarCircle(initials: profile.displayName?.initials ?? "",
                         systemImage: profile.displayName == nil ? DesignTokens.Symbols.profile : nil)
            VStack(spacing: DesignTokens.Spacing.xs) {
                if let name = profile.displayName {
                    Text(name).font(LilyTheme.Fonts.cardTitle)
                } else if profile.isLoading {
                    ProgressView().controlSize(.small)
                }
                if let email = user.email {
                    Text(email).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Button(AppBranding.signOutAction) { Task { await session.signOut() } }
                .lilyGlassButton()
        }
        .animation(.easeInOut(duration: DesignTokens.Duration.fast), value: profile.displayName)
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
