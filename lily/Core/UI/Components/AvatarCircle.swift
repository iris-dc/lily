import SwiftUI

/// Initials (or a glyph) in a tinted glass circle: the profile's avatar, a group's mark in its row, a member's in the
/// roster. The diameter comes from `DesignTokens.Layout.avatarSmall` / `avatarMedium` / `avatarSize`.
struct AvatarCircle: View {
    let initials: String
    /// Drawn instead of the initials when given (a group's event type).
    var systemImage: String?
    var size: CGFloat = DesignTokens.Layout.avatarSize
    var tint: Color = .lilyAccent
    var tintOpacity: Double = DesignTokens.Opacity.glassTint

    var body: some View {
        Group {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(LilyTheme.Fonts.avatarInitials(size: size))
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
