import SwiftUI

/// Sign-in options, presented as a sheet from the landing screen or the guest profile: a navigation bar with Close, the
/// title under it and the three provider buttons centred in the room below, so the half sheet carries no empty band
/// under them. The email form pushed over it puts its own back button in the same bar (`EmailSignInView.backButton`),
/// so the two titles sit at one height; with a bar on the form alone, its title sat a bar's height lower than this one.
struct SignInSheet: View {
    @State private var viewModel: SignInViewModel
    /// The content's height at the medium detent, the smallest it is seen at: the providers come back into view while
    /// the sheet is still shrinking from the form's large detent, and buttons centred in the taller height jumped to
    /// their places at the end. They are centred in this height whatever the sheet's.
    @State private var restHeight: CGFloat?
    /// Medium for the providers and the form at rest; the form grows the sheet to large before a field takes the focus,
    /// so the keyboard never pushes the sheet and its bar's comings and goings move nothing, and gives it back when the
    /// focus goes (`EmailSignInView.focus`).
    @State private var detent: PresentationDetent = .medium
    private let session: SessionController
    private let errorCenter: ErrorCenter
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize

    init(session: SessionController, errorCenter: ErrorCenter) {
        self.session = session
        self.errorCenter = errorCenter
        _viewModel = State(initialValue: SignInViewModel(session: session))
    }

    var body: some View {
        NavigationStack {
            ContentScreen {
                GeometryReader { proxy in
                    // A scroll view for the accessibility type sizes, where the title and the three buttons outgrow even
                    // the full sheet; a fixed column squeezed the title out of view and cut the labels to "Continue…".
                    ScrollView {
                        column
                            .frame(minHeight: restHeight ?? proxy.size.height, alignment: .top)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                    .onChange(of: proxy.size.height, initial: true) { _, height in
                        if height > 0 { restHeight = min(restHeight ?? height, height) }
                    }
                }
            }
            .onChange(of: typeSize, initial: true) { detent = restDetent }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { closeButton }
            }
            .navigationDestination(isPresented: $viewModel.isEmailFormPresented) {
                EmailSignInView(session: session, detent: formDetent)
            }
        }
        .presentationDetents([.medium, .large], selection: $detent)
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

    /// Where the sheet rests with no keyboard up: half, or full at the accessibility type sizes, where half shows the
    /// title alone.
    private var restDetent: PresentationDetent { typeSize.isAccessibilitySize ? .large : .medium }

    /// The form's view of the detent: it asks for medium when the focus goes, which here means the resting detent.
    private var formDetent: Binding<PresentationDetent> {
        Binding(get: { detent }, set: { detent = $0 == .medium ? restDetent : $0 })
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
