import SwiftUI

/// Email + password form, pushed inside the sign-in sheet.
struct EmailSignInView: View {
    @State private var viewModel: EmailSignInViewModel
    @FocusState private var focusedField: Field?

    private enum Field { case email, password }

    init(session: SessionController) {
        _viewModel = State(initialValue: EmailSignInViewModel(session: session))
    }

    var body: some View {
        ContentScreen {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
                ScreenTitle(text: viewModel.mode.title, subtitle: AppBranding.emailSignInSubtitle)
                fields
                submitButton
                modeToggle
                Spacer()
            }
            .padding(DesignTokens.Spacing.xl)
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { focusedField = .email }
        // The sheet cannot reach this view model, so the form stops its own submit when it goes away.
        .onDisappear { viewModel.cancel() }
    }

    private var fields: some View {
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
            SecureField(AppBranding.passwordFieldPlaceholder, text: $viewModel.password)
                .textContentType(viewModel.mode == .signUp ? .newPassword : .password)
                .focused($focusedField, equals: .password)
                .submitLabel(.go)
                .onSubmit { viewModel.submit() }
                .lilyField()
            Text(viewModel.passwordHint)
                .font(LilyTheme.Fonts.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
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
    }

    private var modeToggle: some View {
        Button {
            withAnimation(.smooth(duration: DesignTokens.Duration.fast)) { viewModel.toggleMode() }
        } label: {
            Text(viewModel.mode.toggleLabel)
                .frame(maxWidth: .infinity)
                .tappableTextLabel()
        }
        .font(LilyTheme.Fonts.caption)
        .buttonStyle(.borderless)
        .foregroundStyle(Color.lilyAccent)
    }
}

/// Glass capsule around a text field. A minimum rather than a fixed height, so large Dynamic Type stays inside it.
private struct LilyFieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .frame(minHeight: DesignTokens.Layout.fieldHeight)
            .glassEffect(.regular, in: .capsule)
    }
}

private extension View {
    func lilyField() -> some View { modifier(LilyFieldStyle()) }
}

#Preview {
    NavigationStack { EmailSignInView(session: AppDependencies.makeMock().sessionController) }
}
