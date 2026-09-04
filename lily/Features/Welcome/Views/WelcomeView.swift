import SwiftUI

/// Entry screen: hero, three providers, and a quiet path into the app without an account.
struct WelcomeView: View {
    @State private var viewModel: WelcomeViewModel
    private let session: SessionController
    @Environment(\.dismiss) private var dismiss

    init(session: SessionController) {
        self.session = session
        _viewModel = State(initialValue: WelcomeViewModel(session: session))
    }

    var body: some View {
        ZStack {
            AuroraBackground()
            VStack(spacing: 0) {
                Spacer()
                hero
                Spacer()
                providers
                skipButton
            }
            .padding(.horizontal, DesignTokens.Spacing.xl)
            .padding(.bottom, DesignTokens.Spacing.lg)
        }
        .sheet(isPresented: $viewModel.isEmailSheetPresented) {
            EmailSignInSheet(session: session)
        }
        .onChange(of: session.state.isInsideApp) { _, isInside in
            if isInside { dismiss() }
        }
    }

    private var hero: some View {
        VStack(spacing: DesignTokens.Spacing.xl) {
            SportGlyphCycler()
            VStack(spacing: DesignTokens.Spacing.sm) {
                Wordmark()
                Text("Find your next game.")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var providers: some View {
        GlassEffectContainer(spacing: DesignTokens.Spacing.md) {
            VStack(spacing: DesignTokens.Spacing.md) {
                ProviderButton(provider: .apple,
                               isLoading: viewModel.authenticatingProvider == .apple,
                               isDisabled: viewModel.isBusy) {
                    Task { await viewModel.signInWithApple() }
                }
                ProviderButton(provider: .google,
                               isLoading: viewModel.authenticatingProvider == .google,
                               isDisabled: viewModel.isBusy) {
                    Task { await viewModel.signInWithGoogle() }
                }
                ProviderButton(provider: .email, isDisabled: viewModel.isBusy) {
                    viewModel.presentEmailSignIn()
                }
            }
        }
    }

    private var skipButton: some View {
        Button("Continue without an account") { viewModel.continueAsGuest() }
            .font(LilyTheme.Fonts.caption)
            .foregroundStyle(.secondary)
            .buttonStyle(.plain)
            .frame(height: DesignTokens.Layout.controlHeight)
            .padding(.top, DesignTokens.Spacing.sm)
            .disabled(viewModel.isBusy)
    }
}

#Preview("Welcome") {
    WelcomeView(session: AppDependencies.makeMock().sessionController)
}
