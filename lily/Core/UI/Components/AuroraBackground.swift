import SwiftUI

/// Ember mesh: a slowly flowing red-on-black gradient under live film grain, behind every screen. It fades in from
/// nothing when the screen appears. Frozen on its first frame when Reduce Motion is on (the fade is kept: it is a
/// crossfade, not movement).
struct AuroraBackground: View {
    var intensity: Double = 1

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isRevealed = false

    var body: some View {
        ZStack {
            Color.lilySurface
            TimelineView(.animation(minimumInterval: DesignTokens.Aurora.frameInterval, paused: reduceMotion)) { context in
                // Explicit ZStack: two views returned from the timeline closure would be laid out as a stack, not layered.
                let time = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
                ZStack {
                    mesh(at: time)
                        .opacity(intensity)
                    FilmGrainOverlay(time: time)
                }
                .opacity(isRevealed ? 1 : 0)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: DesignTokens.Aurora.revealDuration)) { isRevealed = true }
        }
    }

    private func mesh(at time: TimeInterval) -> some View {
        MeshGradient(width: AuroraGeometry.gridSize,
                     height: AuroraGeometry.gridSize,
                     points: AuroraGeometry.points(at: time),
                     colors: LilyTheme.auroraColors(intensities: AuroraGeometry.cellIntensities(at: time)),
                     smoothsColors: DesignTokens.Aurora.smoothsColors)
    }
}

#Preview { AuroraBackground() }
