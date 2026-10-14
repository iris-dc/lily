import SwiftUI

/// Initials (or a glyph) in a tinted glass circle: the profile's avatar, a group's mark in its row, a member's in the
/// roster. The diameter comes from `DesignTokens.Layout.avatarSmall` / `avatarMedium` / `avatarSize`. A glyph that is
/// a mark rather than an avatar (`GlassGlyph`) brings its own font and colour; the initials' metrics in ink otherwise.
///
/// The tint says what the circle stands for: an accent circle is a person (profiles, rosters, invitees), a secondary
/// one is a mark (groups, event types, tournaments, the inbox's invite cards, another sender's avatar in a room). Every
/// amber mark sits at `DesignTokens.Opacity.secondaryGlassTint`, `GlassGlyph` and the intro room's header included,
/// the strength of the `EventTypeChip` drawn on the same cards.
struct AvatarCircle: View {
    /// What the circle stands for; the glass colour and its strength follow.
    enum Tint {
        /// A person: `Color.lilyAccent` at `DesignTokens.Opacity.glassTint`.
        case accent
        /// A mark: `Color.lilySecondary` at `DesignTokens.Opacity.secondaryGlassTint`.
        case secondary
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
                    .font(glyphFont ?? LilyTheme.Fonts.avatarInitials(size: size))
                    .foregroundStyle(glyphColor ?? .primary)
            } else {
                Text(initials)
                    .font(LilyTheme.Fonts.avatarInitials(size: size))
            }
        }
        .frame(width: size, height: size)
        .glassEffect(.regular.tint(glassColor), in: .circle)
        .accessibilityHidden(true)
    }

    private var glassColor: Color {
        switch tint {
        case .accent: Color.lilyAccent.opacity(DesignTokens.Opacity.glassTint)
        case .secondary: Color.lilySecondary.opacity(DesignTokens.Opacity.secondaryGlassTint)
        }
    }
}

extension AvatarCircle {
    /// A glyph alone, for a mark that has no name to take initials from (the inbox, a tournament's sport, the map card's
    /// event type). Declared in an extension so the memberwise initializer stays for the initials.
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
            AvatarCircle(systemImage: EventType.running.symbolName, size: DesignTokens.Layout.avatarSmall, tint: .secondary)
        }
    }
}
