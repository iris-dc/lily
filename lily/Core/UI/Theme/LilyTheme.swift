import SwiftUI

/// Semantic styling that isn't a plain color asset. Colors live in `Assets.xcassets` (`Color.lily*`).
enum LilyTheme {
    enum Fonts {
        /// SF Pro Display with tight tracking everywhere: the wordmark, the landing headline and screen titles.
        static func wordmark(size: CGFloat = DesignTokens.Typography.wordmarkSize) -> Font {
            .system(size: size, weight: .semibold)
        }
        static var headline: Font { .system(size: DesignTokens.Typography.headlineSize, weight: .bold) }
        static var screenTitle: Font { .system(.largeTitle, weight: .bold) }
        static var cardTitle: Font { .system(.title3, design: .default, weight: .semibold) }
        static var button: Font { .system(.body, design: .default, weight: .semibold) }
        static var caption: Font { .system(.footnote, design: .default, weight: .medium) }
    }

    /// Ember mesh colors, row by row, for the 4x4 aurora. `intensities` scale each cell's opacity (ripple and breath).
    /// The app is dark-only for now, so there is a single palette: maroon mass, raspberry core, amber ember on near-black.
    /// The core has its own colorset (`LilyAuroraCore`) so retuning the interactive accent leaves the background alone.
    static func auroraColors(intensities: [Double]) -> [Color] {
        zip(AuroraPalette.roles, intensities).map { auroraColor(for: $0, intensity: $1) }
    }

    private static func auroraColor(for role: AuroraRole, intensity: Double) -> Color {
        switch role {
        case .surface:
            return .lilySurface
        case .mass(let density):
            return scaled(.lilyAccentDeep, opacity: AuroraPalette.massOpacity(density), by: intensity)
        case .core:
            return scaled(.lilyAuroraCore, opacity: DesignTokens.Aurora.coreOpacity, by: intensity)
        case .ember:
            return scaled(.lilySecondary, opacity: DesignTokens.Aurora.emberOpacity, by: intensity)
        }
    }

    /// `opacity` times the cell's ripple `intensity`, clamped: a crest over a dense cell would otherwise exceed one.
    private static func scaled(_ color: Color, opacity: Double, by intensity: Double) -> Color {
        color.opacity(min(1, opacity * intensity))
    }
}
