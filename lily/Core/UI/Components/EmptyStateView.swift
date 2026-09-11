import SwiftUI

struct EmptyStateView: View {
    let symbolName: String
    let title: String
    let message: String
    /// Optional call to action under the message, in the app's standard button shape.
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: symbolName)
        } description: {
            Text(message)
        } actions: {
            if let actionTitle, let action {
                Button(action: action) { Text(actionTitle).fullWidthButtonLabel() }
                    .lilyProminentButton()
            }
        }
    }
}
