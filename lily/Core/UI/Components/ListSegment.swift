import SwiftUI

/// The segment of a detail that draws a list view model's state inside the detail's margins: a spinner before the
/// first answer, the cards whenever there are some, else the empty or the failed state the caller worded. The other
/// spinner/empty/failed screens (Explore, Discover, Home, the inbox) branch differently and keep their own.
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
