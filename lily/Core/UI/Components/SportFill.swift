import SwiftUI

extension LilyTheme {
    /// The sport marks' fill: maroon low, the accent high, so the mark carries the app's red without competing with a
    /// prominent button's flat accent.
    static var sportGradient: LinearGradient {
        LinearGradient(colors: [.lilyAccentDeep, .lilyAccent], startPoint: .bottomLeading, endPoint: .topTrailing)
    }
}

extension View {
    /// Draws the sport fill behind the view in `shape`, with a hairline rim and a soft accent glow that lift it off the
    /// glass it sits on. A plain fill, not glass: it is a mark.
    func sportFill<S: InsettableShape>(in shape: S) -> some View {
        background {
            shape
                .fill(LilyTheme.sportGradient)
                .overlay {
                    shape.strokeBorder(.white.opacity(DesignTokens.Opacity.sportMarkRim),
                                       lineWidth: DesignTokens.Layout.sportMarkRimWidth)
                }
                .shadow(color: .lilyAccent.opacity(DesignTokens.Opacity.sportMarkGlow),
                        radius: DesignTokens.Layout.sportMarkGlowRadius)
        }
    }
}
