import SwiftUI

/// Sign-in options, presented as a sheet from the landing screen or the guest profile: a navigation bar with Close, the
/// title under it and the three provider buttons centred in the room below, so the half sheet carries no empty band
/// under them. The email form pushed over it swaps Close for the system back button in the same bar, so its title sits
/// where this screen's does; with a bar on the form alone, its title sat a bar's height lower than this one and dropped
/// another 16 pt half a second after the push, when the bar's inset settled.
struct SignInSheet: View {
    @State private var viewModel: SignInViewModel
    /// The content's height with the keyboard down, the smallest it is seen at: a sheet the keyboard pushes up is
    /// extended down to the screen's bottom behind it, and buttons centred in that height jumped to their places when
    /// the keyboard went. They are centred in this height whatever the sheet's.
    @State private var restHeight: CGFloat?
    /// Medium for the providers and the form at rest; the form grows the sheet to large before a field takes the focus,
    /// so the keyboard never pushes the sheet and its bar's comings and goings move nothing (`EmailSignInView.focus`).
    @State private var detent: PresentationDetent = .medium
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
                GeometryReader { proxy in
                    column
                        .frame(height: restHeight ?? proxy.size.height, alignment: .top)
                        .onChange(of: proxy.size.height, initial: true) { _, height in
                            if height > 0 { restHeight = min(restHeight ?? height, height) }
                        }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { closeButton }
            }
            .navigationDestination(isPresented: $viewModel.isEmailFormPresented) {
                EmailSignInView(session: session, detent: $detent)
            }
        }
        .presentationDetents([.medium, .large], selection: $detent)
        .onChange(of: viewModel.isEmailFormPresented) { _, presented in
            if !presented { withAnimation(.smooth(duration: DesignTokens.Duration.normal)) { detent = .medium } }
        }
        .lilyFormSheet()
        // A sheet is drawn above the root, so the shared popup mounted there would sit behind this one.
        .errorPopup(errorCenter)
        // Guests are already inside the app, so watch for a user rather than for entering the app.
        .onChange(of: session.state.user) { _, user in
            if user != nil { dismiss() }
        }
        // Closed by Close or a swipe down; nothing may finish signing in once it is gone.
        .onDisappear { viewModel.cancel() }
    }

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: DesignTokens.Symbols.dismiss)
        }
        .accessibilityLabel(AppBranding.Forms.close)
        .accessibilityIdentifier(AccessibilityIdentifiers.signInClose)
    }

    private var column: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
            ScreenTitle(text: AppBranding.signInSheetTitle, subtitle: AppBranding.signInSheetSubtitle)
            Spacer(minLength: 0)
            providers
            Spacer(minLength: 0)
        }
        .padding(DesignTokens.Spacing.xl)
        .readableColumn()
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
