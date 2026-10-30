import QuartzCore
import SwiftUI

/// Runs one of the viewer's moves on the display's clock, a frame at a time: the way along it, 0 to 1 on `curve` over
/// `duration`, goes to `apply`, which writes the shared state both sides of the composer line draw from. SwiftUI's own
/// animation of that state ran once per hierarchy, each on its own clock, and the chat's half of the picture drew a frame
/// behind the cover's; one clock and one value put both halves on the same frame. A new run cancels the one before,
/// whose completion never comes; `cancel` ends a run with the viewer.
@MainActor
final class ViewerMoveDriver {
    private let clock: any FrameClock
    private var start: CFTimeInterval = 0
    private var duration: TimeInterval = 0
    private var curve = UnitCurve.linear
    private var apply: ((Double) -> Void)?
    private var completion: (() -> Void)?

    init(clock: any FrameClock) {
        self.clock = clock
    }

    convenience init() {
        self.init(clock: DisplayLinkFrameClock())
    }

    var isRunning: Bool { apply != nil }

    /// Starts a move at `now` on the clock's timeline; from the next frame on, `apply` gets the way.
    func run(duration: TimeInterval,
             curve: UnitCurve,
             now: CFTimeInterval = CACurrentMediaTime(),
             apply: @escaping (Double) -> Void,
             completion: @escaping () -> Void) {
        cancel()
        self.duration = duration
        self.curve = curve
        self.apply = apply
        self.completion = completion
        start = now
        clock.start { [weak self] timestamp in self?.step(at: timestamp) }
    }

    func cancel() {
        clock.stop()
        apply = nil
        completion = nil
    }

    /// Where the move is at `elapsed`: `curve` over the fraction of `duration` gone, whole once the duration is.
    nonisolated static func fraction(elapsed: TimeInterval, duration: TimeInterval, curve: UnitCurve) -> Double {
        guard duration > 0 else { return 1 }
        return curve.value(at: min(1, max(0, elapsed / duration)))
    }

    /// One frame: the value for the moment it will be shown (`timestamp`); the frame at or past the end is exactly the
    /// end, and the move hands over once.
    func step(at timestamp: CFTimeInterval) {
        let fraction = Self.fraction(elapsed: timestamp - start, duration: duration, curve: curve)
        apply?(fraction)
        guard fraction >= 1 else { return }
        let completion = self.completion
        cancel()
        completion?()
    }
}
