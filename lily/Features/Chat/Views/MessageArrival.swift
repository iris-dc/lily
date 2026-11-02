import SwiftUI

/// How a row leaves the transcript (a discarded bubble): it fades and shrinks into its sender's corner, a bubble into
/// the bottom corner on its side, a chip or a note into the bottom edge; under Reduce Motion it is cut, since the
/// transition does not animate under the nil `Animation.messageArrival`. A row arrives through `MessageArrivalCurve`,
/// drawn from a clock by `ChatRowView`, never through an insertion transition.
struct MessageRemovalTransition: Transition {
    let corner: UnitPoint
    let motion: MotionPreference

    init(for row: ChatRow, motion: MotionPreference) {
        corner = row.arrivalCorner
        self.motion = motion
    }

    /// The size a leaving row shrinks to: its own under Reduce Motion, where the row is cut rather than shrunk.
    nonisolated static func leavingScale(motion: MotionPreference) -> CGFloat {
        motion.allowsMovement ? DesignTokens.MessageArrival.scale : 1
    }

    /// Only the leaving phase changes the row: an inserted one is drawn as it is, its arrival is the clock's.
    func body(content: Content, phase: TransitionPhase) -> some View {
        let isLeaving = phase == .didDisappear
        content
            .opacity(isLeaving ? 0 : 1)
            .scaleEffect(isLeaving ? Self.leavingScale(motion: motion) : 1, anchor: corner)
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
    /// The transcript's spring, or none under Reduce Motion (`withAnimation(nil)` applies the change at once).
    nonisolated static func messageArrival(_ motion: MotionPreference) -> Animation? {
        guard motion.allowsMovement else { return nil }
        return .spring(duration: DesignTokens.MessageArrival.duration, bounce: DesignTokens.MessageArrival.bounce)
    }
}
