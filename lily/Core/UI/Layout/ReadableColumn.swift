import SwiftUI

extension View {
    /// Caps a column of text and controls at a readable measure and centres it; on a screen narrower than the cap this
    /// changes nothing, so the iPhone layouts stay as they are.
    func readableColumn(maxWidth: CGFloat = DesignTokens.Layout.readableWidth) -> some View {
        frame(maxWidth: maxWidth)
            .frame(maxWidth: .infinity)
    }
}

extension View {
    /// A detail screen's content inside its margin and the readable column, for the pieces a screen lays out one by
    /// one when something else (a bracket) must keep the whole width.
    func inReadableColumn() -> some View {
        padding(.horizontal, DesignTokens.Spacing.xl)
            .readableColumn()
    }
}
