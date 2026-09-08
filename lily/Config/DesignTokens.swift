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
        /// Delay between each preview card appearing on the landing screen.
        static let previewCardStagger: TimeInterval = 0.12
    }

    enum Layout {
        static let buttonHeight: CGFloat = 48
        static let controlHeight: CGFloat = 44
        static let dismissButtonSize: CGFloat = 30
        static let swipeDismissDistance: CGFloat = 20
        static let chipVerticalPadding: CGFloat = 6
        static let providerIconSize: CGFloat = 22
        static let avatarSize: CGFloat = 72
        static let capacityBarHeight: CGFloat = 6
        static let popupMaxWidth: CGFloat = 520
        /// Landing preview deck: card offsets and tilt for the stacked event cards.
        static let previewCardTilt: Double = 2
        static let previewCardShift: CGFloat = 18
        static let previewCardWidth: CGFloat = 310
        static let mapPinSize: CGFloat = 40
        static let mapSelectedCardWidth: CGFloat = 340
        /// How far (in unit-square terms) the aurora's interior mesh points wander.
        static let auroraDriftAmplitude: Float = 0.18
    }

    enum Opacity {
        static let glassTint: Double = 0.22
        static let subtle: Double = 0.65
        static let faint: Double = 0.35
        static let auroraLight: Double = 0.55
        /// Aurora strength on the landing screen, calmer than on the launch screen.
        static let auroraLanding: Double = 0.8
        /// How strongly the secondary color tints its glass badges.
        static let secondaryGlassTint: Double = 0.28
        /// Secondary-colored hint in the aurora, kept subtle so red stays dominant.
        static let auroraSecondaryHint: Double = 0.22
    }

    enum Typography {
        static let wordmarkSize: CGFloat = 28
        static let wordmarkTracking: CGFloat = -1.2
        static let headlineSize: CGFloat = 44
        static let headlineTracking: CGFloat = -1.8
        static let headlineLineSpacing: CGFloat = -4
        static let titleTracking: CGFloat = -0.5
    }

    /// SF Symbol names, so icons stay consistent across screens.
    enum Symbols {
        static let location = "mappin.and.ellipse"
        static let distance = "location"
        static let list = "list.bullet"
        static let map = "map"
        static let time = "clock"
        static let error = "exclamationmark.circle.fill"
        static let dismiss = "xmark"
        static let apple = "apple.logo"
        static let email = "envelope"
        static let explore = "sparkles"
        static let myEvents = "calendar"
        static let addEvent = "calendar.badge.plus"
        static let profile = "person.crop.circle"
        static let search = "magnifyingglass"
    }
}
