import SwiftUI

/// Glyph in a fixed-width column, so a stack of `Label`s keeps one text edge even when the symbols differ in width.
/// The column scales with Dynamic Type like the glyphs do, and rows align on the first baseline so a wrapped title
/// keeps its glyph on the first line.
struct IconColumnLabelStyle: LabelStyle {
    @ScaledMetric(relativeTo: .body) private var column = DesignTokens.Layout.labelIconColumn

    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.sm) {
            configuration.icon
                .frame(width: column)
            configuration.title
        }
    }
}

extension LabelStyle where Self == IconColumnLabelStyle {
    static var iconColumn: IconColumnLabelStyle { IconColumnLabelStyle() }
}
