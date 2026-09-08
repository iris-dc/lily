import SwiftUI

struct ProfileView: View {
    let session: SessionController
    @State private var isSignInPresented = false

    var body: some View {
        NavigationStack {
            ZStack {
                AuroraBackground(intensity: DesignTokens.Opacity.faint)
                VStack(spacing: DesignTokens.Spacing.xl) {
                    if let user = session.state.user {
                        signedIn(user)
                    } else {
                        guest
                    }
                    Spacer()
                }
                .padding(DesignTokens.Spacing.xl)
            }
            .navigationTitle("Profile")
        }
        .sheet(isPresented: $isSignInPresented) {
            SignInSheet(session: session)
        }
    }

    private func signedIn(_ user: AuthUser) -> some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Text(user.initials)
                .font(.title.weight(.bold))
                .frame(width: DesignTokens.Layout.avatarSize, height: DesignTokens.Layout.avatarSize)
                .glassEffect(.regular.tint(Color.lilyAccent.opacity(DesignTokens.Opacity.glassTint)), in: .circle)
            VStack(spacing: DesignTokens.Spacing.xs) {
                Text(user.displayName).font(LilyTheme.Fonts.cardTitle)
                if let email = user.email {
                    Text(email).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Button("Sign out") { Task { await session.signOut() } }
                .font(LilyTheme.Fonts.button)
                .lilyGlassButton()
                .controlSize(.large)
        }
    }

    private var guest: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                Text("You're browsing as a guest").font(LilyTheme.Fonts.cardTitle)
                Text("Sign in to create events, join games and chat with players.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button(AppBranding.signInAction) { isSignInPresented = true }
                    .font(LilyTheme.Fonts.button)
                    .lilyProminentButton()
                    .controlSize(.large)
            }
        }
    }
}
