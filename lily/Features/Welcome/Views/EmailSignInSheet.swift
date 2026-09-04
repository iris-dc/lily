import SwiftUI

struct EmailSignInSheet: View {
    @State private var viewModel: EmailSignInViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?

    private enum Field { case email, password }

    init(session: SessionController) {
        _viewModel = State(initialValue: EmailSignInViewModel(session: session))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AuroraBackground(intensity: DesignTokens.Opacity.faint)
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
                    ScreenTitle(text: viewModel.mode.title, subtitle: "Use your email and a password.")
                    fields
                    submitButton
                    modeToggle
                    Spacer()
                }
                .padding(DesignTokens.Spacing.xl)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear { focusedField = .email }
    }

    private var fields: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            TextField("Email", text: $viewModel.email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .email)
                .submitLabel(.next)
                .onSubmit { focusedField = .password }
                .lilyField()
            SecureField("Password", text: $viewModel.password)
                .textContentType(viewModel.mode == .signUp ? .newPassword : .password)
                .focused($focusedField, equals: .password)
                .submitLabel(.go)
                .onSubmit { Task { await submit() } }
                .lilyField()
            Text(viewModel.passwordHint)
                .font(LilyTheme.Fonts.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var submitButton: some View {
        Button {
            Task { await submit() }
        } label: {
            HStack {
                Text(viewModel.mode.submitLabel)
                if viewModel.isSubmitting { ProgressView().controlSize(.small) }
            }
            .fullWidthButtonLabel()
        }
        .lilyProminentButton()
        .disabled(!viewModel.canSubmit)
    }

    private var modeToggle: some View {
        Button(viewModel.mode.toggleLabel) {
            withAnimation(.smooth(duration: DesignTokens.Duration.fast)) { viewModel.toggleMode() }
        }
        .font(LilyTheme.Fonts.caption)
        .buttonStyle(.plain)
        .foregroundStyle(Color.lilyAccent)
        .frame(maxWidth: .infinity)
    }

    private func submit() async {
        if await viewModel.submit() { dismiss() }
    }
}

private struct LilyFieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .frame(height: DesignTokens.Layout.buttonHeight)
            .glassEffect(.regular, in: .capsule)
    }
}

private extension View {
    func lilyField() -> some View { modifier(LilyFieldStyle()) }
}

#Preview {
    EmailSignInSheet(session: AppDependencies.makeMock().sessionController)
}
