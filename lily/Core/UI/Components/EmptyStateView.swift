import SwiftUI

struct EmptyStateView: View {
    let symbolName: String
    let title: String
    let message: String
    /// Optional call to action under the message: a prominent capsule that hugs its title.
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: symbolName)
        } description: {
            Text(message)
        } actions: {
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .lilyProminentButton(sizing: .fitted)
            }
        }
    }
}
