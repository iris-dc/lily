import SwiftUI

/// The create form in a sheet: Cancel and Create in the bar, the fields below. Closes itself once the backend answered.
struct CreateEventSheet: View {
    @State private var viewModel: CreateEventViewModel
    private let errorCenter: ErrorCenter
    @Environment(\.dismiss) private var dismiss

    private typealias Copy = AppBranding.Events.Create

    init(viewModel: CreateEventViewModel, errorCenter: ErrorCenter) {
        _viewModel = State(initialValue: viewModel)
        self.errorCenter = errorCenter
    }

    var body: some View {
        NavigationStack {
            ContentScreen {
                EventDraftForm(viewModel: viewModel)
            }
            .navigationTitle(Copy.title)
            .navigationBarTitleDisplayMode(.inline)
            // The semantic placements get the native sheet treatment (a `.borderless` Cancel became an icon-sized
            // circle, "Ca…"). Create keeps the toolbar's own glass and size: hiding that glass left the disabled
            // prominent capsule as black text on nothing.
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { cancelButton }
                ToolbarItem(placement: .confirmationAction) { submitButton }
            }
            .tint(Color.lilyAccent)
        }
        .presentationDragIndicator(.visible)
        // Swiping the sheet away mid-request would leave the outcome unknown to the user.
        .interactiveDismissDisabled(viewModel.isSubmitting)
        // A sheet is drawn above the root, so the shared popup mounted there would sit behind this one.
        .errorPopup(errorCenter)
        .task { await viewModel.prepare() }
        .onChange(of: viewModel.createdEvent) {
            if viewModel.createdEvent != nil { dismiss() }
        }
    }

    private var cancelButton: some View {
        Button(Copy.cancel, role: .cancel) { dismiss() }
            .disabled(viewModel.isSubmitting)
            .accessibilityIdentifier(AccessibilityIdentifiers.createCancel)
    }

    /// Disabled until the draft is complete; the footers under the form say what is missing.
    private var submitButton: some View {
        Button {
            Task { await viewModel.submit() }
        } label: {
            if viewModel.isSubmitting {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityLabel(Copy.submit)
            } else {
                Text(Copy.submit)
            }
        }
        .lilyProminentButton(sizing: .fitted, controlSize: nil)
        .disabled(!viewModel.canSubmit)
        .accessibilityIdentifier(AccessibilityIdentifiers.createSubmit)
    }
}

#Preview {
    let dependencies = AppDependencies.makeMock()
    CreateEventSheet(viewModel: dependencies.makeCreateEventViewModel { _ in }, errorCenter: dependencies.errorCenter)
}
