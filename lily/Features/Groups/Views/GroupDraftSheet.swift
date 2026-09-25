import SwiftUI

/// What a sheet over `GroupDraftForm` needs from its view model, so creating and editing a group share one screen.
protocol GroupDraftEditing: AnyObject, Observable {
    var draft: GroupDraft { get set }
    var issues: [GroupDraft.Issue] { get }
    var isSubmitting: Bool { get }
    var canSubmit: Bool { get }
    /// The backend answered; the sheet closes.
    var isDone: Bool { get }
    func submit() async
}

extension CreateGroupViewModel: GroupDraftEditing {
    var isDone: Bool { createdGroup != nil }
}

extension EditGroupViewModel: GroupDraftEditing {
    var isDone: Bool { updatedGroup != nil }
}

/// The group form in a sheet: Cancel and the submit button in the bar, the fields below. Closes itself once the
/// backend answered.
struct GroupDraftSheet<Model: GroupDraftEditing>: View {
    @State private var viewModel: Model
    private let title: String
    private let submitTitle: String
    private let allowsVisibilityChoice: Bool
    private let errorCenter: ErrorCenter
    @Environment(\.dismiss) private var dismiss

    private typealias Copy = AppBranding.Groups.Create

    init(viewModel: Model, title: String, submitTitle: String, allowsVisibilityChoice: Bool, errorCenter: ErrorCenter) {
        _viewModel = State(initialValue: viewModel)
        self.title = title
        self.submitTitle = submitTitle
        self.allowsVisibilityChoice = allowsVisibilityChoice
        self.errorCenter = errorCenter
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        NavigationStack {
            ContentScreen {
                GroupDraftForm(draft: $viewModel.draft, issues: viewModel.issues, allowsVisibilityChoice: allowsVisibilityChoice)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(Copy.cancel, role: .cancel) { dismiss() }
                        .disabled(viewModel.isSubmitting)
                        .accessibilityIdentifier(AccessibilityIdentifiers.createGroupCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    DraftSubmitButton(title: submitTitle, isSubmitting: viewModel.isSubmitting, isEnabled: viewModel.canSubmit) {
                        await viewModel.submit()
                    }
                    .accessibilityIdentifier(AccessibilityIdentifiers.createGroupSubmit)
                }
            }
            .tint(Color.lilyAccent)
        }
        .presentationDragIndicator(.visible)
        // Swiping the sheet away mid-request would leave the outcome unknown to the user.
        .interactiveDismissDisabled(viewModel.isSubmitting)
        // A sheet is drawn above the root, so the shared popup mounted there would sit behind this one.
        .errorPopup(errorCenter)
        .onChange(of: viewModel.isDone) {
            if viewModel.isDone { dismiss() }
        }
    }
}

/// The bar's submit button of a draft sheet: a spinner in place of the title while the request runs, disabled until
/// the draft is complete. It keeps the toolbar's own glass and size (see `CreateEventSheet`).
struct DraftSubmitButton: View {
    let title: String
    let isSubmitting: Bool
    let isEnabled: Bool
    let action: () async -> Void

    var body: some View {
        Button {
            Task { await action() }
        } label: {
            if isSubmitting {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityLabel(title)
            } else {
                Text(title)
            }
        }
        .lilyProminentButton(sizing: .fitted, controlSize: nil)
        .disabled(!isEnabled)
    }
}
