import QuartzCore

/// `FrameClock` on Core Animation's display link, at the display's fastest rate (`viewerFrameRateRange`).
@MainActor
final class DisplayLinkFrameClock: NSObject, FrameClock {
    private var link: CADisplayLink?
    private var frame: (@MainActor (CFTimeInterval) -> Void)?

    func start(_ frame: @escaping @MainActor (CFTimeInterval) -> Void) {
        stop()
        self.frame = frame
        let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
        link.preferredFrameRateRange = DesignTokens.Duration.viewerFrameRateRange
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    func stop() {
        link?.invalidate()
        link = nil
        frame = nil
    }

    @objc private func tick(_ link: CADisplayLink) {
        frame?(link.targetTimestamp)
    }
}
