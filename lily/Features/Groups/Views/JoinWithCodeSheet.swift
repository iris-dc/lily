import SwiftUI

/// "Join with code": one field that formats the code as it is typed, Continue once it is complete, then the same
/// preview and join an invite link goes through, with Back to the field.
struct JoinWithCodeSheet: View {
    @State private var viewModel: JoinWithCodeViewModel
    private let dependencies: AppDependencies
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isCodeFocused: Bool

    private typealias Copy = AppBranding.Groups.Invite

    init(viewModel: JoinWithCodeViewModel, dependencies: AppDependencies) {
        _viewModel = State(initialValue: viewModel)
        self.dependencies = dependencies
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        NavigationStack {
            ContentScreen {
                if let preview = viewModel.preview {
                    InvitePreviewContent(viewModel: preview, dependencies: dependencies) { dismiss() }
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) { Button(Copy.back) { viewModel.editCode() } }
                        }
                } else {
                    codeEntry($viewModel.input)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button(AppBranding.Groups.Create.cancel, role: .cancel) { dismiss() }
                            }
                        }
                }
            }
            .navigationTitle(AppBranding.Groups.joinWithCode)
            .navigationBarTitleDisplayMode(.inline)
            .tint(Color.lilyAccent)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .errorPopup(dependencies.errorCenter)
    }

    private func codeEntry(_ input: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
            Text(Copy.codePrompt)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            TextField(Copy.codeField, text: input, prompt: Text(Copy.codePlaceholder))
                .font(LilyTheme.Fonts.inviteCode)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .keyboardType(.asciiCapable)
                .focused($isCodeFocused)
                .submitLabel(.continue)
                .onSubmit { Task { await viewModel.proceed() } }
                .lilyField()
                .accessibilityIdentifier(AccessibilityIdentifiers.inviteCodeField)
            Button(Copy.redeem) { Task { await viewModel.proceed() } }
                .lilyProminentButton()
                .disabled(!viewModel.canContinue)
                .accessibilityIdentifier(AccessibilityIdentifiers.inviteContinue)
            Spacer()
        }
        .padding(DesignTokens.Spacing.xl)
        .onAppear { isCodeFocused = true }
    }
}

#Preview {
    let dependencies = AppDependencies.makeMock()
    JoinWithCodeSheet(viewModel: dependencies.makeJoinWithCodeViewModel { _ in }, dependencies: dependencies)
}
