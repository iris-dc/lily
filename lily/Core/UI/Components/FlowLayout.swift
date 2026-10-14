import SwiftUI

/// Lays subviews out left to right and wraps to the next line when the width runs out, like words in a paragraph.
/// The wrapping rules are `FlowArrangement`'s; this is the `Layout` adapter that measures the subviews for them.
struct FlowLayout: Layout {
    var spacing: CGFloat = DesignTokens.Spacing.sm
    /// Gap between lines; separate because subviews with a tall hit area already keep lines apart.
    var rowSpacing: CGFloat = DesignTokens.Spacing.sm

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        let rows = FlowArrangement.rows(for: sizes(of: subviews, fitting: width), in: width, spacing: spacing)
        return CGSize(width: proposal.width ?? rows.map(\.width).max() ?? 0,
                      height: FlowArrangement.height(of: rows, rowSpacing: rowSpacing))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let measured = sizes(of: subviews, fitting: bounds.width)
        var y = bounds.minY
        for row in FlowArrangement.rows(for: measured, in: bounds.width, spacing: spacing) {
            var x = bounds.minX
            for index in row.indices {
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(measured[index]))
                x += measured[index].width + spacing
            }
            y += row.height + rowSpacing
        }
    }

    /// Each subview's ideal size, unless that is wider than a line: then the line's width is proposed instead, so a
    /// long label truncates within the line rather than running past it.
    private func sizes(of subviews: Subviews, fitting width: CGFloat) -> [CGSize] {
        subviews.map { subview in
            let ideal = subview.sizeThatFits(.unspecified)
            guard let lineWidth = FlowArrangement.proposedWidth(ideal: ideal.width, lineWidth: width) else { return ideal }
            return subview.sizeThatFits(ProposedViewSize(width: lineWidth, height: nil))
        }
    }
}
