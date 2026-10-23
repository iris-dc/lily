import Foundation

/// The attachment viewer's phases and which of its moves may still finish, as rules. Every move that starts (the way
/// in, a spring back, the way out) is numbered, and only the latest one's completion counts, so a spring cut short
/// never ends a newer one. Only an open picture takes the finger: one springing back or on its way out ignores it, and
/// a close taken over from a drag (Close or VoiceOver's escape with a finger down) is never undone by that finger.
/// Pure, so the races are checked without a view.
nonisolated struct ViewerMotion: Equatable, Sendable {
    enum Phase: Equatable, Sendable {
        case opening, open, dragging, settling, closing
    }

    private(set) var phase = Phase.opening
    private var latestMove = 0

    /// Whether a drag moves the picture now.
    var takesDrag: Bool { phase == .open || phase == .dragging }

    /// The way in; answers the move's number for its completion.
    mutating func startOpening() -> Int {
        phase = .opening
        return nextMove()
    }

    /// The finger moved the picture: whether it is the viewer's to move.
    mutating func drag() -> Bool {
        guard takesDrag else { return false }
        phase = .dragging
        return true
    }

    /// Let go short of closing; `nil` when nothing is being dragged any more.
    mutating func startSettling() -> Int? {
        guard phase == .dragging else { return nil }
        phase = .settling
        return nextMove()
    }

    /// The way out, from anything but a way out already under way.
    mutating func startClosing() -> Int? {
        guard phase != .closing else { return nil }
        phase = .closing
        return nextMove()
    }

    /// A move ended: whether it was the latest. The latest way in or spring back leaves the picture open.
    mutating func finish(_ move: Int) -> Bool {
        guard move == latestMove else { return false }
        if phase == .opening || phase == .settling { phase = .open }
        return true
    }

    private mutating func nextMove() -> Int {
        latestMove += 1
        return latestMove
    }
}
