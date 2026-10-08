import SwiftUI

/// The contact form: what the message is about, the message, the reply email prefilled from the account, and Send in
/// the bar; once the message went out the sheet thanks the caller and Done closes it. Mounts its own popup, since a
/// sheet is drawn above the root's.
struct FeedbackSheet: View {
    @State private var viewModel: FeedbackViewModel
    private let errorCenter: ErrorCenter
    @Environment(\.dismiss) private var dismiss

    private typealias Copy = AppBranding.Feedback

    init(viewModel: FeedbackViewModel, errorCenter: ErrorCenter) {
        _viewModel = State(initialValue: viewModel)
        self.errorCenter = errorCenter
    }

    var body: some View {
        NavigationStack {
            ContentScreen {
                if viewModel.isSubmitted {
                    EmptyStateView(symbolName: DesignTokens.Symbols.feedbackSent,
                                   title: Copy.thanks,
                                   message: Copy.thanksMessage)
                } else {
                    form
                }
            }
            .navigationTitle(Copy.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .tint(Color.lilyAccent)
        }
        .presentationDetents([.large])
        .lilyFormSheet()
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(viewModel.isSubmitting)
        // A sheet is drawn above the root, so the shared popup mounted there would sit behind this one.
        .errorPopup(errorCenter)
    }

    private var form: some View {
        Form {
            // A segmented picker in a form draws no label of its own; the section header is its caption.
            Section(Copy.kindTitle) {
                Picker(Copy.kindTitle, selection: $viewModel.draft.kind) {
                    ForEach(FeedbackKind.allCases, id: \.self) { kind in
                        Text(kind.displayName).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .accessibilityIdentifier(AccessibilityIdentifiers.feedbackKind)
            }
            Section {
                TextField(viewModel.draft.kind.messagePlaceholder, text: $viewModel.draft.message, axis: .vertical)
                    .textInputAutocapitalization(.sentences)
                    .lineLimit(DesignTokens.Layout.feedbackMessageLines)
                    .accessibilityIdentifier(AccessibilityIdentifiers.feedbackMessage)
            } header: {
                Text(Copy.messageTitle)
            } footer: {
                hint(for: .message)
            }
            Section {
                TextField(AppBranding.emailFieldPlaceholder, text: $viewModel.draft.replyEmail)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier(AccessibilityIdentifiers.feedbackEmail)
            } header: {
                Text(Copy.replyEmailTitle)
            } footer: {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    hint(for: .replyEmail) ?? Text(Copy.replyEmailFooter)
                    Text(Copy.attachedDetails(viewModel.environment.summary))
                }
            }
        }
        .scrollContentBackground(.hidden)
        .readableColumn()
    }

    /// The field's issue in the accent, or nothing.
    private func hint(for field: FeedbackField) -> Text? {
        viewModel.draft.hint(for: field).map { Text($0).foregroundStyle(Color.lilyAccent) }
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        if viewModel.isSubmitted {
            ToolbarItem(placement: .confirmationAction) {
                Button(Copy.done) { dismiss() }
                    .accessibilityIdentifier(AccessibilityIdentifiers.feedbackDone)
            }
        } else {
            ToolbarItem(placement: .cancellationAction) {
                Button(AppBranding.Events.Create.cancel, role: .cancel) { dismiss() }
                    .disabled(viewModel.isSubmitting)
            }
            ToolbarItem(placement: .confirmationAction) {
                DraftSubmitButton(title: Copy.send, isSubmitting: viewModel.isSubmitting, isEnabled: viewModel.canSubmit) {
                    await viewModel.submit()
                }
                .accessibilityIdentifier(AccessibilityIdentifiers.feedbackSubmit)
            }
        }
    }
}

#Preview {
    let dependencies = AppDependencies.makeMock()
    FeedbackSheet(viewModel: dependencies.makeFeedbackViewModel(), errorCenter: dependencies.errorCenter)
}
