import SwiftUI

/// Ember mesh: a slowly flowing red-on-black gradient under live film grain, behind every screen. Mesh, grain and
/// the fade-in all follow the wall clock (`AuroraGeometry`, `FilmGrain`, `AuroraReveal`), so every instance shows the
/// same frame and a tab, push or sheet that appears mid-fade continues it instead of starting from black. Frozen on
/// its first frame, shown at once, when Reduce Motion is on or the root asks for it (`\.auroraFrozen`, the UI tests'
/// launch argument).
struct AuroraBackground: View {
    var intensity: Double = 1

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.auroraFrozen) private var auroraFrozen

    private var frozen: Bool { reduceMotion || auroraFrozen }

    var body: some View {
        ZStack {
            Color.lilySurface
            TimelineView(.animation(minimumInterval: DesignTokens.Aurora.frameInterval, paused: frozen)) { context in
                // Explicit ZStack: two views returned from the timeline closure would be laid out as a stack, not layered.
                let time = frozen ? 0 : context.date.timeIntervalSinceReferenceDate
                // Read while frozen too, so the clock starts now and not when the setting is switched off later.
                let reveal = AuroraReveal.opacity(at: context.date)
                ZStack {
                    mesh(at: time)
                        .opacity(intensity)
                    FilmGrainOverlay(time: time)
                }
                .opacity(frozen ? 1 : reveal)
            }
        }
        .ignoresSafeArea()
    }

    private func mesh(at time: TimeInterval) -> some View {
        MeshGradient(width: AuroraGeometry.gridSize,
                     height: AuroraGeometry.gridSize,
                     points: AuroraGeometry.points(at: time),
                     colors: LilyTheme.auroraColors(intensities: AuroraGeometry.cellIntensities(at: time)),
                     smoothsColors: DesignTokens.Aurora.smoothsColors)
    }
}

extension EnvironmentValues {
    /// Whether every aurora shows its first frame and never redraws (and the intro's Join ring rests); the root sets
    /// it from the launch argument.
    @Entry var auroraFrozen = false
}

#Preview { AuroraBackground() }
