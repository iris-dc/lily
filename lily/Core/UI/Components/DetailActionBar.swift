import SwiftUI

/// The pinned bar at the bottom of a detail screen, mounted via `safeAreaInset(edge: .bottom)`: quiet icon actions
/// (chat, invite) leading and the primary control trailing, transparent over the content like the wizard's bar, so
/// the one thing to do is always in reach. The detail decides what stands in each slot; an uninvolved reader may get
/// the primary button alone.
struct DetailActionBar<Icons: View, Primary: View>: View {
    @ViewBuilder let icons: () -> Icons
    @ViewBuilder let primary: () -> Primary

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            icons()
            primary()
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, DesignTokens.Layout.detailMargin)
        .padding(.vertical, DesignTokens.Spacing.md)
        .readableColumn()
    }
}

/// A state line in the bar where a button would be ("You're in", "Invite only"): quiet ink on glass so it stays
/// legible over whatever scrolled under the transparent bar.
struct DetailBarNotice: View {
    let text: String

    var body: some View {
        Text(text)
            .font(LilyTheme.Fonts.caption)
            .foregroundStyle(.secondary)
            .lilyChip(.regular)
    }
}
