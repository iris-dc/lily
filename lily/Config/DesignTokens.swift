import SwiftUI

/// Visual constants. Views reference these instead of literal numbers and symbol names.
nonisolated enum DesignTokens {
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let hero: CGFloat = 48
    }

    enum Radius {
        static let sm: CGFloat = 10
        static let md: CGFloat = 16
        static let card: CGFloat = 22
        static let lg: CGFloat = 28
    }

    enum Duration {
        static let fast: TimeInterval = 0.2
        static let normal: TimeInterval = 0.35
        static let slow: TimeInterval = 0.6
        /// One full drift cycle of the aurora background.
        static let auroraCycle: TimeInterval = 18
        /// Redraw cadence of the aurora mesh; 30 fps is plenty for a slow drift and halves GPU work.
        static let auroraFrameInterval: TimeInterval = 1.0 / 30
        static let sportGlyphCycle: TimeInterval = 2.6
    }

    enum Layout {
        static let buttonHeight: CGFloat = 54
        static let controlHeight: CGFloat = 44
        static let dismissButtonSize: CGFloat = 30
        static let swipeDismissDistance: CGFloat = 20
        static let chipVerticalPadding: CGFloat = 6
        static let providerIconSize: CGFloat = 22
        /// Text-based provider glyphs (the Google "G") render slightly smaller than symbol glyphs.
        static let providerTextGlyphSize: CGFloat = 18
        static let avatarSize: CGFloat = 72
        static let capacityBarHeight: CGFloat = 6
        static let popupMaxWidth: CGFloat = 520
        static let heroGlyphSize: CGFloat = 56
        static let heroGlyphBadge: CGFloat = 112
        /// How far (in unit-square terms) the aurora's interior mesh points wander.
        static let auroraDriftAmplitude: Float = 0.18
    }

    enum Opacity {
        static let glassTint: Double = 0.22
        static let subtle: Double = 0.65
        static let faint: Double = 0.35
        static let auroraLight: Double = 0.55
    }

    enum Typography {
        static let wordmarkSize: CGFloat = 76
        static let wordmarkTracking: CGFloat = -4
        static let titleTracking: CGFloat = -0.5
    }

    /// SF Symbol names, so icons stay consistent across screens.
    enum Symbols {
        static let location = "mappin.and.ellipse"
        static let time = "clock"
        static let error = "exclamationmark.circle.fill"
        static let dismiss = "xmark"
        static let apple = "apple.logo"
        static let email = "envelope.fill"
        static let explore = "sparkles"
        static let myEvents = "calendar"
        static let addEvent = "calendar.badge.plus"
        static let profile = "person.crop.circle"
        static let search = "magnifyingglass"
    }
}
