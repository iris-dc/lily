import SwiftUI

/// A titled block of a detail screen: a quiet caption ("Details", "People", "About") over the card or text it names.
struct DetailSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text(title)
                .font(LilyTheme.Fonts.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, DesignTokens.Spacing.xs)
            content()
        }
    }
}
