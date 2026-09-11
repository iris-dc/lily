import SwiftUI

extension View {
    /// Caption-sized glass capsule. `EventTypeChip` (a badge) and the price chip on cards share these metrics so they line
    /// up in one row.
    func lilyChip(_ glass: Glass) -> some View {
        font(LilyTheme.Fonts.caption)
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Layout.chipVerticalPadding)
            .glassEffect(glass, in: .capsule)
    }

    /// Gives a text-only button a finger-sized hit area without changing how it looks.
    func tappableLabel() -> some View {
        frame(minHeight: DesignTokens.Layout.controlHeight)
            .contentShape(.rect)
    }
}
