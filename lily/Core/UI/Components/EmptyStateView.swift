import SwiftUI

struct EmptyStateView: View {
    let symbolName: String
    let title: String
    let message: String

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: symbolName)
        } description: {
            Text(message)
        }
    }
}
