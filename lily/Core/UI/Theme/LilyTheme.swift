import SwiftUI

/// Semantic styling that isn't a plain color asset. Colors live in `Assets.xcassets` (`Color.lily*`).
enum LilyTheme {
    enum Fonts {
        /// SF Pro Display with tight tracking everywhere: the wordmark, the landing headline and screen titles.
        static var wordmark: Font { .system(size: DesignTokens.Typography.wordmarkSize, weight: .semibold) }
        static var headline: Font { .system(size: DesignTokens.Typography.headlineSize, weight: .bold) }
        static var screenTitle: Font { .system(.largeTitle, weight: .bold) }
        static var cardTitle: Font { .system(.title3, design: .default, weight: .semibold) }
        static var button: Font { .system(.body, design: .default, weight: .semibold) }
        static var caption: Font { .system(.footnote, design: .default, weight: .medium) }
    }

    /// Aurora palette per color scheme: 9 colors for a 3x3 mesh, row by row.
    static func auroraColors(for scheme: ColorScheme) -> [Color] {
        switch scheme {
        case .dark:
            [
                .lilySurface, .lilyAccentDeep.opacity(0.55), .lilySurface,
                .lilyAccentDeep.opacity(0.35), .lilyAccent.opacity(0.75), .lilySurface,
                .lilySurface, .lilySurface, .lilySecondary.opacity(DesignTokens.Opacity.auroraSecondaryHint),
            ]
        default:
            [
                .lilySurface, .lilyAccent.opacity(0.28), .lilySurface,
                .lilyAccent.opacity(0.14), .lilyAccent.opacity(DesignTokens.Opacity.auroraLight), .lilySurface,
                .lilySurface, .lilySurface, .lilySecondary.opacity(DesignTokens.Opacity.auroraSecondaryHint),
            ]
        }
    }
}
