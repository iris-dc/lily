import SwiftUI

/// Sign-in options, presented as a sheet from the landing screen or the guest profile.
struct SignInSheet: View {
    @State private var viewModel: SignInViewModel
    private let session: SessionController
    private let errorCenter: ErrorCenter
    @Environment(\.dismiss) private var dismiss

    init(session: SessionController, errorCenter: ErrorCenter) {
        self.session = session
        self.errorCenter = errorCenter
        _viewModel = State(initialValue: SignInViewModel(session: session))
    }

    var body: some View {
        NavigationStack {
            ContentScreen {
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
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        // A sheet is drawn above the root, so the shared popup mounted there would sit behind this one.
        .errorPopup(errorCenter)
        // Guests are already inside the app, so watch for a user rather than for entering the app.
        .onChange(of: session.state.user) { _, user in
            if user != nil { dismiss() }
        }
        // The sheet is closed by swiping down (no Cancel button); nothing may finish signing in once it is gone.
        .onDisappear { viewModel.cancel() }
    }

    private var providers: some View {
        GlassEffectContainer(spacing: DesignTokens.Spacing.md) {
            VStack(spacing: DesignTokens.Spacing.md) {
                ProviderButton(provider: .apple,
                               isLoading: viewModel.authenticatingProvider == .apple,
                               isDisabled: viewModel.isBusy) {
                    viewModel.signInWithApple()
                }
                ProviderButton(provider: .google,
                               isLoading: viewModel.authenticatingProvider == .google,
                               isDisabled: viewModel.isBusy) {
                    viewModel.signInWithGoogle()
                }
                ProviderButton(provider: .email, isDisabled: viewModel.isBusy) {
                    viewModel.presentEmailForm()
                }
            }
        }
    }
}

#Preview {
    let dependencies = AppDependencies.makeMock()
    SignInSheet(session: dependencies.sessionController, errorCenter: dependencies.errorCenter)
}
