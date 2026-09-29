import Foundation

/// The aurora's fade-in, once per process on the wall clock. Every `AuroraBackground` reads the same curve, so a
/// screen that appears while the fade is under way continues it rather than starting from black.
nonisolated enum AuroraReveal {
    /// The first moment any aurora asked; a lazy static, so the clock starts with the first frame of the first one.
    static let start = Date()

    /// Opacity of mesh and grain at `date`: 0 at `start`, eased to 1 over `duration`, 1 from then on.
    static func opacity(at date: Date,
                        start: Date = Self.start,
                        duration: TimeInterval = DesignTokens.Aurora.revealDuration) -> Double {
        guard duration > 0 else { return 1 }
        let progress = min(max(date.timeIntervalSince(start) / duration, 0), 1)
        return easeInOut(progress)
    }

    /// Smoothstep: zero slope at both ends, like SwiftUI's `.easeInOut`.
    private static func easeInOut(_ progress: Double) -> Double {
        progress * progress * (3 - 2 * progress)
    }
}
