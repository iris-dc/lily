import SwiftUI

/// How a row arrives in the transcript: it fades and scales in from its sender's corner (a bubble from the bottom
/// corner on its side, a chip or a note from the bottom edge) while the transcript scrolls it into view; a row leaving
/// (a discarded bubble) fades and shrinks the same way. The slide of the rows above is the scroll view's
/// (`TranscriptScrollPolicy.Action.animateToBottom`), not the row's.
struct MessageArrivalTransition: Transition {
    let corner: UnitPoint

    init(for row: ChatRow) {
        corner = switch row {
        case .message(let messageRow): messageRow.isOwn ? .bottomTrailing : .bottomLeading
        case .pending: .bottomTrailing
        case .day, .system: .bottom
        }
    }

    func body(content: Content, phase: TransitionPhase) -> some View {
        content
            .opacity(phase.isIdentity ? 1 : 0)
            .scaleEffect(phase.isIdentity ? 1 : DesignTokens.MessageArrival.scale, anchor: corner)
    }
}

extension Animation {
    static var messageArrival: Animation {
        .spring(duration: DesignTokens.MessageArrival.duration, bounce: DesignTokens.MessageArrival.bounce)
    }
}
