import SwiftUI

/// Email + password form, pushed inside the sign-in sheet. Its third step, the confirmation code, replaces the
/// credential fields once the pool asks for the code. Its navigation bar holds the system back button, as the sheet's
/// first screen's holds Close, so the two titles sit at one height and nothing shifts after the push.
struct EmailSignInView: View {
    @State private var viewModel: EmailSignInViewModel
    @FocusState private var focusedField: Field?
    /// Whether the secure field is in the hierarchy; a row that looks like it stands in while it is not (`passwordRow`).
    @State private var showsPasswordField = false

    private enum Field { case email, password, passwordStandIn, code }

    init(session: SessionController) {
        _viewModel = State(initialValue: EmailSignInViewModel(session: session))
    }

    /// A scroll view, not a fixed column: at accessibility type sizes the form with the keyboard up outgrows the sheet,
    /// and a fixed `VStack` gets compressed instead (the title rides up under the back button, both header lines truncate).
    /// No field takes focus on appearance: the keyboard would arrive a beat after the push and lift the half sheet with
    /// it, which read as a stutter; the user's tap on a field brings the keyboard and the room for it in one motion.
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
                }
                .padding(DesignTokens.Spacing.xl)
                .readableColumn()
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: viewModel.mode) { _, mode in
            if mode == .confirm { focusedField = .code } else { focusEmail() }
        }
        .onChange(of: focusedField) { _, field in
            if field != .password { showsPasswordField = false }
        }
        // The sheet cannot reach this view model, so the form stops its own submit when it goes away.
        .onDisappear { viewModel.cancel() }
    }

    private var credentialFields: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            TextField(AppBranding.emailFieldPlaceholder, text: $viewModel.email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .email)
                .submitLabel(.next)
                .onSubmit { focusPassword() }
                .lilyField()
                // While the secure field is up, a tap here is taken before the field, so the secure field can go first:
                // a secure sibling at the moment this field takes the focus puts the Passwords bar on its keyboard.
                .overlay {
                    if focusedField == .password {
                        Color.clear
                            .contentShape(.rect)
                            .onTapGesture { focusEmail() }
                            .accessibilityHidden(true)
                    }
                }
                .accessibilityIdentifier(AccessibilityIdentifiers.authEmail)
            passwordRow
            Text(viewModel.passwordHint)
                .font(LilyTheme.Fonts.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// The secure field is in the hierarchy only while it has the focus. Beside a secure field, the email field's
    /// keyboard carries the Passwords bar too, and at every change of focus UIKit drops the bar for a frame and brings it
    /// back; the half sheet followed that as a dip. Alone, the email keyboard has no bar and the password keyboard has
    /// one, so each change of focus is one move of the sheet. While the secure field is out, a plain field drawn like it
    /// (the placeholder, or a bullet per character typed) holds its place; a tap on it brings the secure field back.
    @ViewBuilder
    private var passwordRow: some View {
        if showsPasswordField {
            SecureField(AppBranding.passwordFieldPlaceholder, text: $viewModel.password)
                .textContentType(viewModel.mode == .signUp ? .newPassword : .password)
                .focused($focusedField, equals: .password)
                .submitLabel(.go)
                .onSubmit { viewModel.submit() }
                .lilyField()
                .accessibilityIdentifier(AccessibilityIdentifiers.authPassword)
        } else {
            TextField(AppBranding.passwordFieldPlaceholder, text: .constant(passwordBullets))
                .focused($focusedField, equals: .passwordStandIn)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                .lilyField()
                .overlay {
                    Button(action: focusPassword) { Color.clear.contentShape(.rect) }
                        .buttonStyle(.plain)
                        .accessibilityLabel(AppBranding.passwordFieldPlaceholder)
                        .accessibilityIdentifier(AccessibilityIdentifiers.authPassword)
                }
        }
    }

    private var passwordBullets: String {
        String(repeating: DesignTokens.Typography.secureFieldBullet, count: viewModel.password.count)
    }

    private func focusPassword() {
        showsPasswordField = true
        focusedField = .password
    }

    /// From the secure field, two turns: it must be gone before the email field takes the focus, or its keyboard gets
    /// the bar after all, and a turn with no first responder sends the keyboard away (the sheet dropped 250 pt after
    /// it). The stand-in holds the keyboard for that one turn. From anywhere else there is no secure field to go first.
    private func focusEmail() {
        guard focusedField == .password else {
            focusedField = .email
            return
        }
        showsPasswordField = false
        focusedField = .passwordStandIn
        DispatchQueue.main.async { focusedField = .email }
    }

    private var codeField: some View {
        TextField(AppBranding.confirmationCodePlaceholder, text: $viewModel.code)
            .keyboardType(.numberPad)
            .textContentType(.oneTimeCode)
            .focused($focusedField, equals: .code)
            .lilyField()
            .accessibilityIdentifier(AccessibilityIdentifiers.authConfirmationCode)
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

    /// Text-only action in the accent colour with the standard 44pt hit area.
    private func textButton(_ title: String, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .frame(maxWidth: .infinity)
                .tappableLabel()
        }
        .font(LilyTheme.Fonts.caption)
        .buttonStyle(.borderless)
        .foregroundStyle(Color.lilyAccent)
        .accessibilityIdentifier(identifier)
    }
}

#Preview {
    NavigationStack { EmailSignInView(session: AppDependencies.makeMock().sessionController) }
}
