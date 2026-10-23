import SwiftUI

/// Lays its one row out at the row's own height and takes `fraction` of that height in the transcript, the row placed
/// at its top. As the fraction rises from 0 to 1 the row takes its room frame by frame: the transcript, holding its
/// bottom, moves the rows above up by exactly what the row gained, and the part not yet revealed lies under the
/// composer, so the row comes up from beneath it.
struct RowReveal: Layout {
    var fraction: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let row = subviews.first else { return .zero }
        let size = row.sizeThatFits(ProposedViewSize(width: proposal.width, height: nil))
        return CGSize(width: proposal.width ?? size.width, height: size.height * fraction)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let row = subviews.first else { return }
        row.place(at: bounds.origin, anchor: .topLeading, proposal: ProposedViewSize(width: bounds.width, height: nil))
    }
}
