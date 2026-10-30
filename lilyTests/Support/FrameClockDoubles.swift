import QuartzCore
@testable import lily

/// A `FrameClock` the test ticks by hand.
@MainActor
final class FakeFrameClock: FrameClock {
    private var frame: (@MainActor (CFTimeInterval) -> Void)?

    var isRunning: Bool { frame != nil }

    func start(_ frame: @escaping @MainActor (CFTimeInterval) -> Void) {
        self.frame = frame
    }

    func stop() {
        frame = nil
    }

    func tick(at timestamp: CFTimeInterval) {
        frame?(timestamp)
    }
}
