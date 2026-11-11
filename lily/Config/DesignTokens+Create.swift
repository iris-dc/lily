import SwiftUI

/// The creation wizard's chrome: the step progress mark, the step content's entrance, the type grid and the
/// choice-card symbols.
nonisolated extension DesignTokens.Symbols {
    /// The group type page's "Any type" choice card.
    static let anyType = "asterisk"
    /// The clear button beside the optional finish time's picker.
    static let removeFinishTime = "xmark.circle.fill"
    /// The pick mark beside the price field's currency symbol once it is a menu, secondary ink like the symbol.
    static let currencyMenu = "chevron.up.chevron.down"
}

nonisolated extension DesignTokens.Layout {
    /// The progress mark's capsule height.
    static let wizardProgressBarHeight: CGFloat = 4
    /// How far below its place a step's content starts before easing up on entry.
    static let wizardEntranceOffset: CGFloat = 12
    /// The type steps' grid: columns of compact cards, each at least the 44 pt hit target tall.
    static let wizardTypeColumns = 2
    static let wizardTypeCardHeight: CGFloat = 44
}

nonisolated extension DesignTokens.Opacity {
    /// The track behind the progress mark's accent fill.
    static let wizardProgressTrack: Double = 0.25
}
