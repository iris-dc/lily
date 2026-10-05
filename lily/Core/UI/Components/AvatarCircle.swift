import SwiftUI

/// Initials (or a glyph) in a tinted glass circle: the profile's avatar, a group's mark in its row, a member's in the
/// roster. The diameter comes from `DesignTokens.Layout.avatarSmall` / `avatarMedium` / `avatarSize`. A glyph that is
/// a mark rather than an avatar (`GlassGlyph`) brings its own font and colour; the initials' metrics in ink otherwise.
struct AvatarCircle: View {
    let initials: String
    /// Drawn instead of the initials when given (a group's event type).
    var systemImage: String?
    var size: CGFloat = DesignTokens.Layout.avatarSize
    var tint: Color = .lilyAccent
    var tintOpacity: Double = DesignTokens.Opacity.glassTint
    var glyphFont: Font?
    var glyphColor: Color?

    var body: some View {
        Group {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(glyphFont ?? LilyTheme.Fonts.avatarInitials(size: size))
                    .foregroundStyle(glyphColor ?? .primary)
            } else {
                Text(initials)
                    .font(LilyTheme.Fonts.avatarInitials(size: size))
            }
        }
        .frame(width: size, height: size)
        .glassEffect(.regular.tint(tint.opacity(tintOpacity)), in: .circle)
        .accessibilityHidden(true)
    }
}

#Preview {
    ContentScreen {
        VStack(spacing: DesignTokens.Spacing.lg) {
            AvatarCircle(initials: "AT")
            AvatarCircle(initials: "KK", size: DesignTokens.Layout.avatarMedium, tint: .lilySecondary)
            AvatarCircle(initials: "", systemImage: EventType.running.symbolName, size: DesignTokens.Layout.avatarSmall)
        }
    }
}
