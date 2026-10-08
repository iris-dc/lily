import SwiftUI

/// The faint accent wash behind the row a split view's detail shows: a plain fill, never glass, running a little
/// past the row's text on both sides so the wash reads as the row's and not as a card inside it.
private struct SelectedRowBackground: ViewModifier {
    let isSelected: Bool

    func body(content: Content) -> some View {
        content.background {
            if isSelected {
                RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous)
                    .fill(Color.lilyAccent.opacity(DesignTokens.Opacity.selectedRow))
                    .padding(.horizontal, -DesignTokens.Spacing.sm)
            }
        }
    }
}

extension View {
    /// Marks a conversation row as the one open in a split view's detail; nothing is drawn while `isSelected` is false.
    func selectedRowBackground(_ isSelected: Bool) -> some View {
        modifier(SelectedRowBackground(isSelected: isSelected))
    }
}
