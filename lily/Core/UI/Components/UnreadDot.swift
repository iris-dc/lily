import SwiftUI

/// The accent dot at the end of a group row whose chat has messages the user has not read.
struct UnreadDot: View {
    var body: some View {
        Circle()
            .fill(Color.lilyAccent)
            .frame(width: DesignTokens.Layout.unreadDotSize, height: DesignTokens.Layout.unreadDotSize)
            .accessibilityLabel(AppBranding.Groups.unread)
    }
}

#Preview {
    ContentScreen { UnreadDot() }
}
