import SwiftUI

/// Initials (or a glyph) in a tinted circle: the profile's avatar, a group's mark in its row, a member's in the roster,
/// a game's or a tournament's sport. The diameter comes from `DesignTokens.Layout.avatarSmall` / `avatarMedium` /
/// `avatarSize`. A glyph brings its own font and colour when given; the tint's metrics otherwise.
///
/// The tint is a meaning: accent for a person (profiles, rosters, invitees), secondary for a mark (groups, the inbox's
/// cards) and for another sender's avatar in a room, sport for an event's or a tournament's type. Every amber mark sits
/// at `DesignTokens.Opacity.secondaryGlassTint`. A sport mark is the plain maroon-to-accent fill with a white glyph
/// (`sportFill(in:)`), not glass: a fill is a mark the accent may colour, and amber read as foreign beside the red.
struct AvatarCircle: View {
    /// What the circle stands for; the surface and its strength follow.
    enum Tint {
        case accent
        case secondary
        case sport
    }

    let initials: String
    /// Drawn instead of the initials when given (a group's event type).
    var systemImage: String?
    var size: CGFloat = DesignTokens.Layout.avatarSize
    var tint: Tint = .accent
    var glyphFont: Font?
    var glyphColor: Color?

    var body: some View {
        Group {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(glyphFont ?? defaultGlyphFont)
                    .foregroundStyle(glyphColor ?? (tint == .sport ? .white : .primary))
            } else {
                Text(initials)
                    .font(LilyTheme.Fonts.avatarInitials(size: size))
            }
        }
        .frame(width: size, height: size)
        .modifier(AvatarSurface(tint: tint))
        .accessibilityHidden(true)
    }

    private var defaultGlyphFont: Font {
        tint == .sport ? LilyTheme.Fonts.sportGlyph(size: size) : LilyTheme.Fonts.avatarInitials(size: size)
    }
}

/// The circle under the glyph or the initials: tinted glass, or the sport fill.
private struct AvatarSurface: ViewModifier {
    let tint: AvatarCircle.Tint

    func body(content: Content) -> some View {
        switch tint {
        case .accent:
            content.glassEffect(.regular.tint(Color.lilyAccent.opacity(DesignTokens.Opacity.glassTint)), in: .circle)
        case .secondary:
            content.glassEffect(.regular.tint(Color.lilySecondary.opacity(DesignTokens.Opacity.secondaryGlassTint)),
                                in: .circle)
        case .sport:
            content.sportFill(in: .circle)
        }
    }
}

extension AvatarCircle {
    /// A glyph alone, for a mark with no name to take initials from. In an extension so the memberwise initializer
    /// survives.
    init(systemImage: String,
         size: CGFloat = DesignTokens.Layout.avatarSize,
         tint: Tint = .accent,
         glyphFont: Font? = nil,
         glyphColor: Color? = nil) {
        self.init(initials: "",
                  systemImage: systemImage,
                  size: size,
                  tint: tint,
                  glyphFont: glyphFont,
                  glyphColor: glyphColor)
    }
}

#Preview {
    ContentScreen {
        VStack(spacing: DesignTokens.Spacing.lg) {
            AvatarCircle(initials: "AT")
            AvatarCircle(initials: "KK", size: DesignTokens.Layout.avatarMedium, tint: .secondary)
            AvatarCircle(systemImage: EventType.running.symbolName, size: DesignTokens.Layout.avatarMedium, tint: .sport)
        }
    }
}
