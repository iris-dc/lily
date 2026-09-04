import SwiftUI

/// Semantic styling that isn't a plain color asset. Colors live in `Assets.xcassets` (`Color.lily*`).
nonisolated enum LilyTheme {
    enum Fonts {
        static var wordmark: Font {
            .system(size: DesignTokens.Typography.wordmarkSize, weight: .heavy, design: .default)
        }
        static var screenTitle: Font { .system(.largeTitle, design: .default, weight: .bold) }
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
                .lilySurface, .lilySurface, .lilyAccentDeep.opacity(0.3),
            ]
        default:
            [
                .lilySurface, .lilyAccent.opacity(0.28), .lilySurface,
                .lilyAccent.opacity(0.14), .lilyAccent.opacity(DesignTokens.Opacity.auroraLight), .lilySurface,
                .lilySurface, .lilySurface, .lilyAccentDeep.opacity(0.18),
            ]
        }
    }
}
