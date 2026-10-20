import SwiftUI

/// How a row leaves the transcript (a discarded bubble): it fades and shrinks into its sender's corner, a bubble into
/// the bottom corner on its side, a chip or a note into the bottom edge. A row arrives through `MessageArrivalCurve`,
/// drawn from a clock by `ChatRowView`, never through an insertion transition.
struct MessageRemovalTransition: Transition {
    let corner: UnitPoint

    init(for row: ChatRow) {
        corner = row.arrivalCorner
    }

    /// Only the leaving phase changes the row: an inserted one is drawn as it is, its arrival is the clock's.
    func body(content: Content, phase: TransitionPhase) -> some View {
        let isLeaving = phase == .didDisappear
        content
            .opacity(isLeaving ? 0 : 1)
            .scaleEffect(isLeaving ? DesignTokens.MessageArrival.scale : 1, anchor: corner)
    }
}

extension ChatRow {
    /// The corner a row grows out of and shrinks into: its sender's.
    var arrivalCorner: UnitPoint {
        switch self {
        case .message(let messageRow): messageRow.isOwn ? .bottomTrailing : .bottomLeading
        case .pending: .bottomTrailing
        case .day, .system: .bottom
        }
    }
}

extension Animation {
    static var messageArrival: Animation {
        .spring(duration: DesignTokens.MessageArrival.duration, bounce: DesignTokens.MessageArrival.bounce)
    }
}
