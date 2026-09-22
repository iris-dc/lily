import SwiftUI

/// Email + password form, pushed inside the sign-in sheet. Its third step, the confirmation code, replaces the
/// credential fields once the pool asks for the code.
struct EmailSignInView: View {
    @State private var viewModel: EmailSignInViewModel
    @FocusState private var focusedField: Field?

    private enum Field { case email, password, code }

    init(session: SessionController) {
        _viewModel = State(initialValue: EmailSignInViewModel(session: session))
    }

    var body: some View {
        ContentScreen {
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
                Spacer()
            }
            .padding(DesignTokens.Spacing.xl)
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { focusedField = .email }
        .onChange(of: viewModel.mode) { _, mode in focusedField = mode == .confirm ? .code : .email }
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
                .onSubmit { focusedField = .password }
                .lilyField()
                .accessibilityIdentifier(AccessibilityIdentifiers.authEmail)
            SecureField(AppBranding.passwordFieldPlaceholder, text: $viewModel.password)
                .textContentType(viewModel.mode == .signUp ? .newPassword : .password)
                .focused($focusedField, equals: .password)
                .submitLabel(.go)
                .onSubmit { viewModel.submit() }
                .lilyField()
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
