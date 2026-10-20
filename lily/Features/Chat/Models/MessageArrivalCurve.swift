import SwiftUI

/// A row arriving in the transcript, frame by frame from a clock: it fades in and grows from its sender's corner on one
/// spring. Read off the time since the row arrived, so nothing on the way can cut it short: the row is laid out below the
/// fold and scrolled into view, and a sent message's row turns from the unsent bubble into the stored one mid-way. An
/// insertion transition on the same row lost its fade to both, and the bubble came into view at full strength.
nonisolated struct MessageArrivalCurve: Equatable, Sendable {
    let duration: TimeInterval
    let bounce: Double
    /// The size the row grows from, relative to its own.
    let startScale: Double

    /// The row at one instant: how visible it is and how far it has grown.
    struct Frame: Equatable, Sendable {
        let opacity: Double
        let scale: Double

        static let resting = Frame(opacity: 1, scale: 1)
    }

    /// The transcript's arrival, on its design tokens.
    static let standard = MessageArrivalCurve(duration: DesignTokens.MessageArrival.duration,
                                              bounce: DesignTokens.MessageArrival.bounce,
                                              startScale: Double(DesignTokens.MessageArrival.scale))

    private var spring: Spring { Spring(duration: duration, bounce: bounce) }
    /// The fade's spring: the same without its bounce, so the row only ever brightens.
    private var fade: Spring { Spring(duration: duration, bounce: 0) }

    /// How long the spring takes to come to rest; from then on the row is drawn as it is.
    var settlingDuration: TimeInterval { spring.settlingDuration }

    /// The row `elapsed` seconds after it arrived: invisible at `startScale` until then, at rest once the spring has
    /// settled; the scale keeps the spring's overshoot, the bounce, while the fade rises without one.
    func frame(elapsed: TimeInterval) -> Frame {
        guard elapsed > 0 else { return Frame(opacity: 0, scale: startScale) }
        guard elapsed < settlingDuration else { return .resting }
        let opacity = fade.value(target: 1.0, time: elapsed)
        let growth = spring.value(target: 1.0, time: elapsed)
        return Frame(opacity: min(max(opacity, 0), 1), scale: startScale + (1 - startScale) * growth)
    }
}
