import SwiftUI

/// Glass capsule around a text field. A minimum rather than a fixed height, so large Dynamic Type stays inside it.
private struct LilyFieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .frame(minHeight: DesignTokens.Layout.fieldHeight)
            .glassEffect(.regular, in: .capsule)
    }
}

extension View {
    func lilyField() -> some View { modifier(LilyFieldStyle()) }
}
