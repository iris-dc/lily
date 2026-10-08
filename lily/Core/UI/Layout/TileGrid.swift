import SwiftUI

/// The regular-width stand-in for a sideways carousel: a wrapping grid of fixed-height tiles, as many columns as fit
/// at `tileMinWidth`, showing the first `regularTileCount` of what the carousel would scroll through; "See all" in the
/// section's heading reaches the rest. Compact widths keep their carousel and never draw this.
struct TileGrid<Data: RandomAccessCollection, Content: View>: View where Data.Element: Identifiable {
    let data: Data
    @ViewBuilder let content: (Data.Element) -> Content

    var body: some View {
        LazyVGrid(columns: Self.columns, alignment: .leading, spacing: DesignTokens.Spacing.md) {
            ForEach(Self.shown(of: data)) { element in
                content(element)
            }
        }
        .padding(.horizontal, DesignTokens.Layout.screenMargin)
    }

    nonisolated static var columns: [GridItem] {
        [GridItem(.adaptive(minimum: DesignTokens.Layout.tileMinWidth), spacing: DesignTokens.Spacing.md, alignment: .top)]
    }

    /// The grid's cap: the first `regularTileCount` items, in the order the carousel would show them.
    nonisolated static func shown(of data: Data) -> [Data.Element] {
        Array(data.prefix(DesignTokens.Layout.regularTileCount))
    }
}

extension View {
    /// A tile's frame: the carousel's fixed width (so its rows line up), or the whole cell in a `TileGrid`, at one height.
    func tileFrame(fixedWidth: CGFloat, height: CGFloat, fillsWidth: Bool) -> some View {
        frame(width: fillsWidth ? nil : fixedWidth, height: height)
            .frame(maxWidth: fillsWidth ? .infinity : nil)
    }
}
