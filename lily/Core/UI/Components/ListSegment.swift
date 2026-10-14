import SwiftUI

/// A detail's list segment: a spinner before the first answer, the cards whenever there are some, else the empty or
/// the failed state the caller worded.
struct ListSegment<Content: View>: View {
    let state: ListState
    let empty: EmptyStateView
    let failed: EmptyStateView
    @ViewBuilder let content: () -> Content

    var body: some View {
        switch state {
        case .loading:
            ProgressView().frame(maxWidth: .infinity)
        case .empty:
            empty
        case .failed:
            failed
        case .content:
            content()
        }
    }
}
