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

/// Glass around a field that grows over several lines (the chat composer): the same minimum height as `lilyField()`,
/// in a rounded rectangle because a five-line capsule reads as a blob.
private struct LilyMultilineFieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .padding(.vertical, DesignTokens.Spacing.md)
            .frame(minHeight: DesignTokens.Layout.fieldHeight)
            .glassEffect(.regular, in: .rect(cornerRadius: DesignTokens.Radius.md))
    }
}

extension View {
    func lilyField() -> some View { modifier(LilyFieldStyle()) }

    func lilyMultilineField() -> some View { modifier(LilyMultilineFieldStyle()) }
}
