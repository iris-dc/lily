import QuartzCore

/// `FrameClock` on Core Animation's display link, at the display's fastest rate by default
/// (`viewerFrameRateRange`); a sampler names something slower.
@MainActor
final class DisplayLinkFrameClock: NSObject, FrameClock {
    private var link: CADisplayLink?
    private var frame: (@MainActor (CFTimeInterval) -> Void)?
    private let frameRate: CAFrameRateRange

    init(frameRate: CAFrameRateRange = DesignTokens.Duration.viewerFrameRateRange) {
        self.frameRate = frameRate
    }

    func start(_ frame: @escaping @MainActor (CFTimeInterval) -> Void) {
        stop()
        self.frame = frame
        let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
        link.preferredFrameRateRange = frameRate
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
