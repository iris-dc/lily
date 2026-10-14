import SwiftUI

/// The event form in the shared draft sheet.
struct EventDraftSheet<Model: EventDraftEditing>: View {
    let viewModel: Model
    let title: String
    let submitTitle: String
    let errorCenter: ErrorCenter

    var body: some View {
        DraftSheet(viewModel: viewModel,
                   title: title,
                   submitTitle: submitTitle,
                   cancelIdentifier: AccessibilityIdentifiers.createCancel,
                   submitIdentifier: AccessibilityIdentifiers.createSubmit,
                   errorCenter: errorCenter) { EventDraftForm(viewModel: $0) }
    }
}
