import SwiftUI

/// Email + password form, pushed inside the sign-in sheet. Its third step, the confirmation code, replaces the
/// credential fields once the pool asks for the code. Its navigation bar holds a back button, as the sheet's first
/// screen's holds Close, so the two titles sit at one height and nothing shifts after the push.
struct EmailSignInView: View {
    @State private var viewModel: EmailSignInViewModel
    @FocusState private var focusedField: Field?
    /// The sheet's detent, the sheet's own state: the form grows the sheet before a field takes the focus and gives it
    /// back when the focus goes (`focus(_:)`, `goBack`).
    @Binding private var detent: PresentationDetent
    /// Ride along for the legal sheets the sign-up footnote presents (`LegalSheet`).
    private let errorCenter: ErrorCenter
    private let language: AppLanguage
    @State private var presentedLegal: LegalSheet.Document?
    @Environment(\.dismiss) private var dismiss

    private enum Field { case email, password, code }

    init(session: SessionController, errorCenter: ErrorCenter, language: AppLanguage, detent: Binding<PresentationDetent>) {
        _viewModel = State(initialValue: EmailSignInViewModel(session: session))
        self.errorCenter = errorCenter
        self.language = language
        _detent = detent
    }

    /// A scroll view, not a fixed column: at accessibility type sizes the form with the keyboard up outgrows the sheet,
    /// and a fixed `VStack` gets compressed instead (the title rides up under the back button, both header lines truncate).
    /// No field takes focus on appearance: the keyboard would arrive a beat after the push and lift the half sheet with
    /// it, which read as a stutter; the user's tap on a field grows the sheet and brings the keyboard.
    var body: some View {
        ContentScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
                    ScreenTitle(text: viewModel.mode.title, subtitle: viewModel.subtitle)
                    if viewModel.mode == .confirm {
                        codeField
                    } else {
                        credentialFields
                    }
                    submitButton
                    if viewModel.mode == .confirm {
                        resendButton
                    }
                    modeToggle
                    if viewModel.mode == .signUp {
                        agreementFootnote
                    }
                }
                .padding(DesignTokens.Spacing.xl)
                .readableColumn()
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { backButton }
        }
        .onChange(of: viewModel.mode) { _, mode in focus(mode == .confirm ? .code : .email) }
        // A focus that arrives with the sheet still half (VoiceOver activates a field itself) grows it late rather than
        // leaving the keyboard to push it.
        .onChange(of: focusedField) { _, field in
            withAnimation(.smooth(duration: DesignTokens.Duration.normal)) {
                detent = field == nil ? .medium : .large
            }
        }
        .sheet(item: $presentedLegal) { document in
            LegalSheet(document: document, language: language, errorCenter: errorCenter)
        }
        // The sheet cannot reach this view model, so the form stops its own submit when it goes away.
        .onDisappear { viewModel.cancel() }
    }

    private var credentialFields: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            TextField(AppBranding.emailFieldPlaceholder, text: $viewModel.email)
                .textContentType(.username)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .email)
                .submitLabel(.next)
                .onSubmit { focus(.password) }
                .lilyField()
                .firstTapGrowsTheSheet(detent: detent) { focus(.email) }
                .accessibilityIdentifier(AccessibilityIdentifiers.authEmail)
            SecureField(AppBranding.passwordFieldPlaceholder, text: $viewModel.password)
                .textContentType(viewModel.mode == .signUp ? .newPassword : .password)
                .focused($focusedField, equals: .password)
                .submitLabel(.go)
                .onSubmit { viewModel.submit() }
                .lilyField()
                .firstTapGrowsTheSheet(detent: detent) { focus(.password) }
                .accessibilityIdentifier(AccessibilityIdentifiers.authPassword)
            Text(viewModel.passwordHint)
                .font(LilyTheme.Fonts.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var codeField: some View {
        TextField(AppBranding.confirmationCodePlaceholder, text: $viewModel.code)
            .keyboardType(.numberPad)
            .textContentType(.oneTimeCode)
            .focused($focusedField, equals: .code)
            .lilyField()
            .firstTapGrowsTheSheet(detent: detent) { focus(.code) }
            .accessibilityIdentifier(AccessibilityIdentifiers.authConfirmationCode)
    }

    /// The keyboard never moves the sheet: a half sheet the keyboard pushes up follows every change of the keyboard's
    /// height, and the keyboard's bar (the password manager's suggestions, on both fields) is dropped and rebuilt at
    /// every change of focus, so the sheet dipped and came back each time. The sheet grows to its large detent first,
    /// above where the keyboard reaches, and the field takes the focus once it has; from a sheet already large, at once.
    private func focus(_ field: Field) {
        guard detent != .large else {
            focusedField = field
            return
        }
        withAnimation(.smooth(duration: DesignTokens.Duration.normal)) { detent = .large }
        // The next turn of the main queue, once the detent has reached UIKit; measured, the keyboard then starts 0.3 s
        // after the tap and the sheet never overshoots.
        DispatchQueue.main.async { focusedField = field }
    }

    /// Back in the bar of our own, so the keyboard can start down before the pop. The system back button pops with the
    /// field still focused, and UIKit then takes the keyboard away with no animation: the sheet snapped to its resting
    /// place under the keyboard still up, or the keyboard vanished in a frame over the sheet's extended bottom.
    private var backButton: some View {
        Button(action: goBack) {
            Image(systemName: DesignTokens.Symbols.back)
        }
        .accessibilityLabel(AppBranding.Forms.back)
        .accessibilityIdentifier(AccessibilityIdentifiers.authBack)
    }

    private func goBack() {
        guard focusedField != nil else {
            dismiss()
            return
        }
        focusedField = nil
        // The next turn of the main queue: the keyboard is on its way down and the sheet shrinking when the pop starts.
        DispatchQueue.main.async { dismiss() }
    }

    private var submitButton: some View {
        Button {
            viewModel.submit()
        } label: {
            HStack {
                Text(viewModel.mode.submitLabel)
                if viewModel.isSubmitting { ProgressView().controlSize(.small) }
            }
        }
        .lilyProminentButton()
        .disabled(!viewModel.canSubmit)
        .accessibilityIdentifier(AccessibilityIdentifiers.authSubmit)
    }

    private var resendButton: some View {
        textButton(AppBranding.resendCodeAction, identifier: AccessibilityIdentifiers.authResendCode) {
            viewModel.resendCode()
        }
        .disabled(viewModel.isBusy)
    }

    private var modeToggle: some View {
        textButton(viewModel.mode.toggleLabel, identifier: AccessibilityIdentifiers.authModeToggle) {
            withAnimation(.smooth(duration: DesignTokens.Duration.fast)) { viewModel.toggleMode() }
        }
    }

    /// Text-only action in ink with the standard 44pt hit area.
    private func textButton(_ title: String, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .frame(maxWidth: .infinity)
        }
        .lilyTextButton(font: LilyTheme.Fonts.caption)
        .accessibilityIdentifier(identifier)
    }

    /// Stand-ins formatted into the agreement copy in place of the two document names (`InviteSentence`'s pattern).
    private static let termsMarker = "\u{FFFC}1"
    private static let privacyMarker = "\u{FFFC}2"

    /// "By creating an account you agree to the Terms of use and Privacy policy": one localized sentence whose two
    /// names are tappable runs opening the in-app documents as sheets. Ink and underlined, not the accent, which
    /// never colours text below the headline size; each language orders the sentence its own way around the names.
    private var agreementFootnote: some View {
        Text(agreementText)
            .font(LilyTheme.Fonts.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .environment(\.openURL, OpenURLAction { url in
                guard let document = LegalSheet.Document(agreementURL: url) else { return .systemAction }
                presentedLegal = document
                return .handled
            })
            .accessibilityIdentifier(AccessibilityIdentifiers.authAgreement)
    }

    private var agreementText: AttributedString {
        var text = AttributedString(AppBranding.signUpAgreement(terms: Self.termsMarker, privacy: Self.privacyMarker))
        replaceMarker(Self.termsMarker,
                      with: AppBranding.Moderation.termsLink,
                      opening: AppConfig.Legal.termsLink,
                      in: &text)
        replaceMarker(Self.privacyMarker,
                      with: AppBranding.Moderation.privacyLink,
                      opening: AppConfig.Legal.privacyLink,
                      in: &text)
        return text
    }

    private func replaceMarker(_ marker: String, with name: String, opening url: URL, in text: inout AttributedString) {
        guard let range = text.range(of: marker) else { return }
        var link = AttributedString(name)
        link.link = url
        link.underlineStyle = .single
        link.foregroundColor = Color.lilyInk
        text.replaceSubrange(range, with: link)
    }
}

private extension View {
    /// While the sheet is still half, a tap on the field is taken here and runs `action` (the growth, then the focus)
    /// instead of focusing the field at once, which would bring the keyboard before the sheet has grown and let it push
    /// the sheet. Once the sheet is large the field takes its taps itself.
    func firstTapGrowsTheSheet(detent: PresentationDetent, action: @escaping () -> Void) -> some View {
        overlay {
            if detent != .large {
                Color.clear
                    .contentShape(.rect)
                    .onTapGesture(perform: action)
                    .accessibilityHidden(true)
            }
        }
    }
}

#Preview {
    @Previewable @State var detent: PresentationDetent = .medium
    let dependencies = AppDependencies.makeMock()
    NavigationStack {
        EmailSignInView(session: dependencies.sessionController,
                        errorCenter: dependencies.errorCenter,
                        language: .english,
                        detent: $detent)
    }
}
