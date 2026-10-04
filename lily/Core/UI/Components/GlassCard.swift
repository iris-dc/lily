import SwiftUI

/// Liquid Glass surface used by every card in the app. The whole rectangle is the hit shape: a card is often a
/// `.plain` `NavigationLink`'s label, whose taps otherwise land only where the content draws, so a tap in the gap
/// between two lines did nothing (seen on the tournament card, 2026-10-04).
struct GlassCard<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(DesignTokens.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular, in: .rect(cornerRadius: DesignTokens.Radius.card))
            .contentShape(.rect)
    }
}
