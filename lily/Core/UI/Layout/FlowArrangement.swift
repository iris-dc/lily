import CoreGraphics

/// The wrapping arithmetic behind `FlowLayout`, kept pure because `LayoutSubviews` cannot be built in a test and a chip
/// running past its card at accessibility sizes is the kind of bug that hides in exactly this code.
nonisolated enum FlowArrangement {
    struct Row: Equatable, Sendable {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    /// The width to propose to a subview whose ideal width is `ideal` on a line `lineWidth` wide: `nil` while the ideal
    /// fits or the line is unbounded (the ideal size is used), else the line's width, so a long label truncates within the
    /// line rather than running past it.
    static func proposedWidth(ideal: CGFloat, lineWidth: CGFloat) -> CGFloat? {
        guard lineWidth.isFinite, ideal > lineWidth else { return nil }
        return lineWidth
    }

    /// `sizes` packed in order into rows no wider than `width`, `spacing` between items and none before the first; an
    /// item that would overrun the line starts the next row, an item wider than the line alone still gets a row of its
    /// own (never dropped), an unbounded width gives one row at the content's width, no items give no rows.
    static func rows(for sizes: [CGSize], in width: CGFloat, spacing: CGFloat) -> [Row] {
        var rows: [Row] = []
        var row = Row()
        for (index, size) in sizes.enumerated() {
            if !row.indices.isEmpty, row.width + spacing + size.width > width {
                rows.append(row)
                row = Row()
            }
            row.width += (row.indices.isEmpty ? 0 : spacing) + size.width
            row.height = max(row.height, size.height)
            row.indices.append(index)
        }
        if !row.indices.isEmpty {
            rows.append(row)
        }
        return rows
    }

    /// The rows' heights plus `rowSpacing` between them; zero for none.
    static func height(of rows: [Row], rowSpacing: CGFloat) -> CGFloat {
        rows.map(\.height).reduce(0, +) + rowSpacing * CGFloat(max(rows.count - 1, 0))
    }
}
