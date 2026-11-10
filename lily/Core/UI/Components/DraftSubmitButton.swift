import SwiftUI

/// The submit button of a draft flow: a spinner in place of the title while the request runs, disabled until the
/// draft is complete. The defaults are the draft sheets' toolbar look (`controlSize: nil` keeps the toolbar's own
/// glass and size, see `DraftSheet`'s toolbar); the creation wizard's bottom bar passes `.flexible` and `.large` for
/// the full-width call-to-action look with the same semantics.
struct DraftSubmitButton: View {
    let title: String
    let isSubmitting: Bool
    let isEnabled: Bool
    var sizing: ButtonSizing = .fitted
    var controlSize: ControlSize?
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
        .lilyProminentButton(sizing: sizing, controlSize: controlSize)
        .disabled(!isEnabled)
    }
}
