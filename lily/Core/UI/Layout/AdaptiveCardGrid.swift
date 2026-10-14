import SwiftUI

/// Cards in one column on a compact width (exactly what a `LazyVStack` draws today) and in as many adaptive columns
/// as fit between `cardMinWidth` and `cardMaxWidth` on a regular width.
struct AdaptiveCardGrid<Data: RandomAccessCollection, Content: View>: View where Data.Element: Identifiable {
    let data: Data
    /// One flexible column whatever the width: for a list inside a readable column, which is too narrow for two cards
    /// and where a lone capped card would otherwise sit at the leading edge.
    var singleColumn = false
    @ViewBuilder let content: (Data.Element) -> Content

    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        LazyVGrid(columns: Self.columns(for: singleColumn ? .compact : sizeClass),
                  alignment: .leading,
                  spacing: DesignTokens.Spacing.md) {
            ForEach(data) { element in
                content(element)
            }
        }
    }

    /// The grid's one rule: a single flexible column unless the width is regular. Cells align at the top, so two cards
    /// of different heights in one row start on the same line instead of centring on each other.
    nonisolated static func columns(for sizeClass: UserInterfaceSizeClass?) -> [GridItem] {
        guard sizeClass == .regular else {
            return [GridItem(.flexible(), spacing: DesignTokens.Spacing.md, alignment: .top)]
        }
        return [GridItem(.adaptive(minimum: DesignTokens.Layout.cardMinWidth, maximum: DesignTokens.Layout.cardMaxWidth),
                         spacing: DesignTokens.Spacing.md,
                         alignment: .top)]
    }
}
