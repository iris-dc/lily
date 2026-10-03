import SwiftUI

struct ProfileView: View {
    let session: SessionController
    let language: LanguageStore
    let errorCenter: ErrorCenter
    @State private var isSignInPresented = false

    var body: some View {
        NavigationStack {
            ContentScreen {
                VStack(spacing: DesignTokens.Spacing.xl) {
                    if let user = session.state.user {
                        signedIn(user)
                    } else {
                        guest
                    }
                    LanguageRow(language: language)
                    Spacer()
                }
                .padding(.horizontal, DesignTokens.Layout.screenMargin)
                .padding(.vertical, DesignTokens.Spacing.xl)
            }
            .navigationTitle(AppBranding.profileTitle)
        }
        .sheet(isPresented: $isSignInPresented) {
            SignInSheet(session: session, errorCenter: errorCenter)
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
