import SwiftUI

/// A vertical scroll with pull-to-refresh: the one place the gesture is declared, so every list refreshes the same way
/// and an empty state stays refreshable too.
struct RefreshableScroll<Content: View>: View {
    let action: () async -> Void
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView { content() }
            .refreshable { await action() }
    }
}
