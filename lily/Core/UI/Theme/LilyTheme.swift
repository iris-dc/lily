import SwiftUI

/// Semantic styling that isn't a plain color asset. Colors live in `Assets.xcassets` (`Color.lily*`).
enum LilyTheme {
    enum Fonts {
        /// The launch screen's wordmark (`Wordmark`, its one caller). SF Pro with tight tracking is the design language
        /// every font here follows.
        static func wordmark(size: CGFloat) -> Font {
            .system(size: size, weight: .semibold)
        }
        static var headline: Font { headline(scale: 1) }
        /// The landing headline at a fraction of its size, for a line that fits in one only when shrunk.
        static func headline(scale: CGFloat) -> Font {
            .system(size: DesignTokens.Typography.headlineSize * scale, weight: .bold)
        }
        static var screenTitle: Font { .system(.largeTitle, weight: .bold) }
        static var cardTitle: Font { .system(.title3, design: .default, weight: .semibold) }
        static var sectionTitle: Font { .system(.title2, design: .default, weight: .bold) }
        static var button: Font { .system(.body, design: .default, weight: .semibold) }
        /// The glyph of the floating create button: heavier and larger than button text so it reads from across the screen.
        static var floatingAction: Font { .system(.title2, design: .default, weight: .bold) }
        static var caption: Font { .system(.footnote, design: .default, weight: .medium) }
        /// A symbol as a mark in a `GlassGlyph`: the type glyph on the map's preview card.
        static var glyph: Font { .system(.title3, design: .default, weight: .medium) }
    }

    /// The one date-and-time style of the facts cards and match rows ("15 Jan 2027 at 18:30"), in the app language.
    /// A `static var`, never a `static let`: a `let` would freeze the first language.
    nonisolated enum DateStyles {
        static var dateTime: Date.FormatStyle { dateTime(locale: AppLocale.locale) }

        static func dateTime(locale: Locale) -> Date.FormatStyle {
            Date.FormatStyle(date: .abbreviated, time: .shortened, locale: locale)
        }
    }

    /// The one selected look for toggling controls (map pins, `ChoiceChip`): accent glass with a white label when on,
    /// plain glass with an ink label when off.
    static func selectionGlass(isSelected: Bool) -> Glass {
        isSelected ? .regular.tint(Color.lilyAccent) : .regular
    }

    static func selectionLabelColor(isSelected: Bool) -> Color {
        isSelected ? .white : .lilyInk
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
