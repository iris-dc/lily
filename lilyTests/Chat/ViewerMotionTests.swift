import Testing
@testable import lily

/// The viewer's phases: only the latest move finishes, a picture on its way in or open takes the finger, and a close is
/// final.
struct ViewerMotionTests {
    @Test func theWayInEndsOpenAndADragSpringsBack() {
        var motion = ViewerMotion()
        let opening = motion.startOpening()
        let opened = motion.finish(opening)
        #expect(opened && motion.phase == .open)

        let dragged = motion.drag()
        #expect(dragged && motion.phase == .dragging)
        let settling = motion.startSettling()
        let draggedWhileSettling = motion.drag()
        #expect(settling != nil && !draggedWhileSettling, "a spring back ignores the finger")
        let settled = settling.map { motion.finish($0) } ?? false
        #expect(settled && motion.phase == .open)
    }

    /// A drag taken up on the way in carries on when the way in ends: the picture is the finger's, not open.
    @Test func aDragOnTheWayInIsTheFingers() {
        var motion = ViewerMotion()
        let opening = motion.startOpening()
        let dragged = motion.drag()
        let finished = motion.finish(opening)

        #expect(dragged && finished && motion.phase == .dragging)
        let settling = motion.startSettling()
        #expect(settling != nil)
    }

    /// A move cut short by a newer one does not end it: its completion comes late and is stale.
    @Test func aStaleCompletionChangesNothing() {
        var motion = ViewerMotion()
        let opening = motion.startOpening()
        let closing = motion.startClosing()
        let staleFinished = motion.finish(opening)

        #expect(closing != nil, "Close during the way in")
        #expect(!staleFinished && motion.phase == .closing, "the way in's completion does not reopen it")
        let closed = closing.map { motion.finish($0) } ?? false
        #expect(closed)
    }

    /// Close with a finger down: the finger's next moves and its letting go change nothing, and a second Close is
    /// ignored.
    @Test func aCloseDuringADragIsFinal() {
        var motion = ViewerMotion()
        _ = motion.finish(motion.startOpening())
        _ = motion.drag()

        let closing = motion.startClosing()
        let draggedAfter = motion.drag()
        let settledAfter = motion.startSettling()
        let closedAgain = motion.startClosing()

        #expect(closing != nil && !draggedAfter && settledAfter == nil && closedAgain == nil)
        let closed = closing.map { motion.finish($0) } ?? false
        #expect(motion.phase == .closing && closed)
    }
}
