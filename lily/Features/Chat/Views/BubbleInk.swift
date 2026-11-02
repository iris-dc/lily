import SwiftUI

/// The colours inside a bubble, by whose it is: white on the caller's accent bubble, ink and the accent on everyone
/// else's surface bubble. Every part of a bubble reads them from here rather than choosing by `own` itself.
struct BubbleInk {
    let own: Bool

    /// Body text, and what a quote's or a card's wash is made of.
    var primary: Color { own ? .white : .lilyInk }
    /// Marks: a quote's bar, a poll's tick. Text, buttons included, reads `primary` or `secondary`.
    var accent: Color { own ? .white : .lilyAccent }
    /// Captions, where `.secondary` would turn grey on the accent.
    var secondary: Color { own ? Color.white.opacity(DesignTokens.Opacity.secondaryOnAccent) : .secondary }
    /// The bubble's own fill.
    var background: Color { own ? .lilyAccent : .lilySurface }
}
