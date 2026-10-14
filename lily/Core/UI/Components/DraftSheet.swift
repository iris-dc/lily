import SwiftUI

/// The shell every create/edit sheet shares: Cancel and the submit button in the bar, the feature's form below,
/// closing itself once the backend answered.
struct DraftSheet<Model: DraftSubmitting, Form: View>: View {
    @State private var viewModel: Model
    private let title: String
    private let submitTitle: String
    private let cancelIdentifier: String
    private let submitIdentifier: String
    private let errorCenter: ErrorCenter
    private let form: (Model) -> Form
    @Environment(\.dismiss) private var dismiss

    init(
        viewModel: Model,
        title: String,
        submitTitle: String,
        cancelIdentifier: String,
        submitIdentifier: String,
        errorCenter: ErrorCenter,
        @ViewBuilder form: @escaping (Model) -> Form
    ) {
        _viewModel = State(initialValue: viewModel)
        self.title = title
        self.submitTitle = submitTitle
        self.cancelIdentifier = cancelIdentifier
        self.submitIdentifier = submitIdentifier
        self.errorCenter = errorCenter
        self.form = form
    }

    var body: some View {
        NavigationStack {
            ContentScreen {
                form(viewModel)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            // The semantic placements get the native sheet treatment (a `.borderless` Cancel became an icon-sized
            // circle, "Ca…"). The submit button keeps the toolbar's own glass and size: hiding that glass left the
            // disabled prominent capsule as black text on nothing.
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppBranding.Forms.cancel, role: .cancel) { dismiss() }
                        .disabled(viewModel.isSubmitting)
                        .accessibilityIdentifier(cancelIdentifier)
                }
                ToolbarItem(placement: .confirmationAction) {
                    DraftSubmitButton(title: submitTitle, isSubmitting: viewModel.isSubmitting, isEnabled: viewModel.canSubmit) {
                        await viewModel.submit()
                    }
                    .accessibilityIdentifier(submitIdentifier)
                }
            }
            .tint(Color.lilyAccent)
        }
        .lilyFormSheet()
        .presentationDragIndicator(.visible)
        // Swiping the sheet away mid-request would leave the outcome unknown to the user.
        .interactiveDismissDisabled(viewModel.isSubmitting)
        // A sheet is drawn above the root, so the shared popup mounted there would sit behind this one.
        .errorPopup(errorCenter)
        .task { await viewModel.prepare() }
        .onChange(of: viewModel.isDone) {
            if viewModel.isDone { dismiss() }
        }
    }
}
