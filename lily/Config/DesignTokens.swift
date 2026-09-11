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
    }

    enum Radius {
        static let md: CGFloat = 16
        static let card: CGFloat = 22
    }

    enum Duration {
        static let fast: TimeInterval = 0.2
        static let normal: TimeInterval = 0.35
        static let slow: TimeInterval = 0.6
        /// Delay between each preview card appearing on the landing screen.
        static let previewCardStagger: TimeInterval = 0.12
    }

    enum Layout {
        /// Horizontal inset of screen content, equal to the leading margin of a large navigation title on iPhone,
        /// so text laid directly on a screen lines up with its title.
        static let screenMargin: CGFloat = Spacing.lg
        static let buttonHeight: CGFloat = 48
        static let controlHeight: CGFloat = 44
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
        /// Starting scale of a preview card before it settles into the deck.
        static let previewCardEntranceScale: CGFloat = 0.94
        static let mapPinSize: CGFloat = 40
        /// Growth of a map pin when selected.
        static let mapPinSelectedScale: CGFloat = 1.15
        static let mapSelectedCardWidth: CGFloat = 340
    }

    enum Opacity {
        static let glassTint: Double = 0.22
        /// How strongly the secondary color tints its glass badges.
        static let secondaryGlassTint: Double = 0.28
    }

    /// The ember mesh behind every screen (full strength on launch, `landingIntensity` and `contentIntensity` elsewhere): a 4x4
    /// `MeshGradient` whose points drift and whose red carries a slow travelling brightness ripple, under live film grain.
    /// Slow but plainly visible: the user should see the red flow within a few seconds without it fighting the headline.
    enum Aurora {
        /// Mesh strength on the landing screen, calmer than the full-strength launch screen.
        static let landingIntensity: Double = 0.85
        /// Mesh strength behind content screens (lists, details, profile, sign-in), where text and cards sit on top.
        static let contentIntensity: Double = 0.55
        /// Redraw cadence; 30 fps is plenty for a slow drift and halves GPU work.
        static let frameInterval: TimeInterval = 1.0 / 30
        /// Bicubic color smoothing: the glows melt into the dark like a blurred light, no visible cell edges.
        static let smoothsColors = true
        /// The whole background fades in from nothing when a screen appears, so the glow arrives rather than pops.
        static let revealDuration: TimeInterval = 3.5
        /// Drift periods in seconds. Pairwise incommensurate, so the combined motion never visibly repeats.
        static let driftPeriods: [TimeInterval] = [19, 23, 29, 37]
        /// Period of the core glow breathing.
        static let glowPeriod: TimeInterval = 23
        /// How far (in unit-square terms) an interior mesh point wanders on each axis.
        static let driftAmplitude: Float = 0.15
        /// How far an edge point slides along its edge; smaller so the silhouette only breathes.
        static let edgeDriftAmplitude: Float = 0.08
        /// Weights of the sines summed per axis, largest first; they add up to one so the drift amplitude is exact.
        static let driftWeights: [Float] = [0.5, 0.3, 0.2]
        /// Peak-to-center swing of the core opacity while it breathes.
        static let glowSwing: Double = 0.2
        /// Period of the brightness wave that travels down the main diagonal of the mesh, so the red visibly flows.
        static let ripplePeriod: TimeInterval = 29
        /// Peak-to-center swing of a cell's opacity as the main ripple passes over it.
        static let rippleSwing: Double = 0.25
        /// Period of a second, slower wave across the other diagonal that breaks the regular beat of the first.
        static let rippleCrossPeriod: TimeInterval = 41
        /// Peak-to-center swing of the cross wave, half the main one so it only modulates the flow.
        static let rippleCrossSwing: Double = 0.12
        /// Phase lag per diagonal step (row + column) between neighbouring cells, in radians: about one wave on screen.
        static let rippleSpacing: Double = 0.9
        /// Core (hot `lilyAuroraCore`) opacity before the glow swing is applied.
        static let coreOpacity: Double = 0.55
        /// Opacity of the densest part of the maroon mass.
        static let massDense: Double = 0.55
        /// Opacity where the mass thins out towards the middle of the screen.
        static let massMid: Double = 0.38
        /// Opacity of the outer fringe of the mass, just before it fades into the surface.
        static let massThin: Double = 0.18
        /// The single amber ember in the bottom-left corner, faint so red stays dominant.
        static let emberOpacity: Double = 0.2
        /// Side length in noise pixels of each tiled film-grain texture.
        static let grainTileSize = 128
        /// Device pixels per noise pixel: 2 makes the grain coarse enough to read as film rather than dither.
        static let grainPixelSize: CGFloat = 2
        /// Pre-generated grain tiles cycled while animating; random noise at this count never reads as a loop.
        static let grainFrameCount = 12
        /// How often the grain changes tile: film-like flicker, under the mesh's own redraw rate.
        static let grainFrameRate: Double = 24
        /// Film grain strength; the noise adds light (`plusLighter`) onto the near-black surface, a whisper, not dirt.
        static let grainOpacity: Double = 0.08
        /// Seed of the deterministic grain noise, so every launch and every test sees the same texture.
        static let grainSeed: UInt64 = 0x4C69_6C79
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
    }
}
