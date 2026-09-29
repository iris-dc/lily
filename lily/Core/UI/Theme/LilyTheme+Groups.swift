import SwiftUI

extension LilyTheme.Fonts {
    /// Initials inside an avatar circle of `size` points.
    static func avatarInitials(size: CGFloat) -> Font {
        .system(size: size * DesignTokens.Layout.avatarInitialsFraction, weight: .bold)
    }
}
