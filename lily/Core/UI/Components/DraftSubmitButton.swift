import SwiftUI

/// The bar's submit button of a draft sheet: a spinner in place of the title while the request runs, disabled until
/// the draft is complete. `controlSize: nil` keeps the toolbar's own glass and size (see `DraftSheet`'s toolbar).
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
