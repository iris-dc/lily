import SwiftUI

/// A row arriving in the transcript, frame by frame from a clock: it takes its room from no height, fades in and grows
/// from its sender's corner on one spring. Read off the time since the row arrived, so nothing on the way can cut it
/// short: a sent message's row turns from the unsent bubble into the stored one mid-way, which an insertion transition
/// on the same row would lose its fade to.
nonisolated struct MessageArrivalCurve: Equatable, Sendable {
    let duration: TimeInterval
    let bounce: Double
    /// The size the row grows from, relative to its own.
    let startScale: Double

    /// The row at one instant: how visible it is, how far it has grown, and how much of its height it takes.
    struct Frame: Equatable, Sendable {
        let opacity: Double
        let scale: Double
        let reveal: Double

        static let resting = Frame(opacity: 1, scale: 1, reveal: 1)
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

    /// The row `elapsed` seconds after it arrived: invisible, at `startScale` and taking no height until then, at rest
    /// once the spring has settled; the scale keeps the spring's overshoot, the bounce, while the fade and the height
    /// rise without one, so the rows above never move back down.
    func frame(elapsed: TimeInterval) -> Frame {
        guard elapsed > 0 else { return Frame(opacity: 0, scale: startScale, reveal: 0) }
        guard elapsed < settlingDuration else { return .resting }
        let rise = min(max(fade.value(target: 1.0, time: elapsed), 0), 1)
        let growth = spring.value(target: 1.0, time: elapsed)
        return Frame(opacity: rise, scale: startScale + (1 - startScale) * growth, reveal: rise)
    }
}
