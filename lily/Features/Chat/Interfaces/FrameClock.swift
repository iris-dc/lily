import QuartzCore

/// A clock that calls back once per frame of the display, with the time the frame will be shown at, until `stop`. The
/// app's is Core Animation's display link (`DisplayLinkFrameClock`); a test ticks one by hand.
@MainActor
protocol FrameClock: AnyObject {
    func start(_ frame: @escaping @MainActor (CFTimeInterval) -> Void)
    func stop()
}
