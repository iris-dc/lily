import SwiftUI

/// A symbol as a mark in an amber glass circle, the type glyph on the map's preview card: the same circle as
/// `AvatarCircle`, with the glyph in the secondary colour at `LilyTheme.Fonts.glyph` instead of the initials' metrics.
struct GlassGlyph: View {
    let systemName: String

    var body: some View {
        AvatarCircle(initials: "",
                     systemImage: systemName,
                     size: DesignTokens.Layout.controlHeight,
                     tint: .lilySecondary,
                     glyphFont: LilyTheme.Fonts.glyph,
                     glyphColor: .lilySecondary)
    }
}
