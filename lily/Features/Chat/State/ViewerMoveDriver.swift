import QuartzCore
import SwiftUI

/// Runs one of the viewer's moves on the display's clock, a frame at a time: the way along it, 0 to 1 on `curve` over
/// `duration`, goes to `apply`, which writes the shared state both sides of the composer line draw from. SwiftUI's own
/// animation of that state ran once per hierarchy, each on its own clock, and the chat's half of the picture drew a frame
/// behind the cover's; one clock and one value put both halves on the same frame. A new run cancels the one before,
/// whose completion never comes; `cancel` ends a run with the viewer.
@MainActor
final class ViewerMoveDriver: NSObject {
    private var link: CADisplayLink?
    private var start: CFTimeInterval = 0
    private var duration: TimeInterval = 0
    private var curve = UnitCurve.linear
    private var apply: ((Double) -> Void)?
    private var completion: (() -> Void)?

    func run(duration: TimeInterval,
             curve: UnitCurve,
             apply: @escaping (Double) -> Void,
             completion: @escaping () -> Void) {
        cancel()
        self.duration = duration
        self.curve = curve
        self.apply = apply
        self.completion = completion
        start = CACurrentMediaTime()
        let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    func cancel() {
        link?.invalidate()
        link = nil
        apply = nil
        completion = nil
    }

    /// Where the move is at `elapsed`: `curve` over the fraction of `duration` gone, whole once the duration is.
    nonisolated static func fraction(elapsed: TimeInterval, duration: TimeInterval, curve: UnitCurve) -> Double {
        guard duration > 0 else { return 1 }
        return curve.value(at: min(1, max(0, elapsed / duration)))
    }

    /// Each frame writes the value for the moment the frame will be shown; the last one is exactly the end.
    @objc private func tick(_ link: CADisplayLink) {
        let fraction = Self.fraction(elapsed: link.targetTimestamp - start, duration: duration, curve: curve)
        apply?(fraction)
        guard fraction >= 1 else { return }
        let completion = self.completion
        cancel()
        completion?()
    }
}
