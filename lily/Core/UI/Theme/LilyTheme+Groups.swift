import SwiftUI

extension LilyTheme.Fonts {
    /// An invite code, grouped in fours: monospaced so the groups line up whatever the symbols.
    static var inviteCode: Font { .system(.title2, design: .monospaced, weight: .semibold) }

    /// Initials inside an avatar circle of `size` points.
    static func avatarInitials(size: CGFloat) -> Font {
        .system(size: size * DesignTokens.Layout.avatarInitialsFraction, weight: .bold)
    }
}
