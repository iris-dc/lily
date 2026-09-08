import SwiftUI

/// Sign-in options, presented as a sheet from the landing screen or the guest profile.
struct SignInSheet: View {
    @State private var viewModel: SignInViewModel
    private let session: SessionController
    @Environment(\.dismiss) private var dismiss

    init(session: SessionController) {
        self.session = session
        _viewModel = State(initialValue: SignInViewModel(session: session))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AuroraBackground(intensity: DesignTokens.Opacity.faint)
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
                    ScreenTitle(text: AppBranding.signInSheetTitle, subtitle: AppBranding.signInSheetSubtitle)
                    providers
                    Spacer()
                }
                .padding(DesignTokens.Spacing.xl)
            }
            .navigationDestination(isPresented: $viewModel.isEmailFormPresented) {
                EmailSignInView(session: session)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onChange(of: session.state.isInsideApp) { _, isInside in
            if isInside { dismiss() }
        }
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
                    viewModel.presentEmailForm()
                }
            }
        }
    }
}

#Preview {
    SignInSheet(session: AppDependencies.makeMock().sessionController)
}
