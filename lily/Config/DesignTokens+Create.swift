import SwiftUI

/// The creation wizard's chrome: the step progress mark, the step content's entrance and the choice-card symbols.
nonisolated extension DesignTokens.Symbols {
    /// The group type page's "Any type" choice card.
    static let anyType = "asterisk"
}

nonisolated extension DesignTokens.Layout {
    /// The progress mark's capsule height.
    static let wizardProgressBarHeight: CGFloat = 4
    /// How far below its place a step's content starts before easing up on entry.
    static let wizardEntranceOffset: CGFloat = 12
}

nonisolated extension DesignTokens.Opacity {
    /// The track behind the progress mark's accent fill.
    static let wizardProgressTrack: Double = 0.25
}
