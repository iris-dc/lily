import SwiftUI

struct SportChip: View {
    let sport: SportType

    var body: some View {
        Label(sport.displayName, systemImage: sport.symbolName)
            .font(LilyTheme.Fonts.caption)
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Layout.chipVerticalPadding)
            .glassEffect(.regular.tint(Color.lilyAccent.opacity(DesignTokens.Opacity.glassTint)), in: .capsule)
    }
}
