import SwiftUI

/// Slowly drifting red-on-black mesh gradient. Static when Reduce Motion is on.
struct AuroraBackground: View {
    var intensity: Double = 1

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        TimelineView(.animation(minimumInterval: DesignTokens.Duration.auroraFrameInterval, paused: reduceMotion)) { context in
            let time = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
            MeshGradient(
                width: AuroraGeometry.gridSize,
                height: AuroraGeometry.gridSize,
                points: AuroraGeometry.points(at: time),
                colors: LilyTheme.auroraColors(for: colorScheme)
            )
        }
        .opacity(intensity)
        .background(Color.lilySurface)
        .ignoresSafeArea()
    }
}

/// Pure geometry for the mesh so it can be unit tested and stays out of the view.
nonisolated enum AuroraGeometry {
    /// The mesh is 3x3: corners and edges stay pinned, interior points drift on slow sine waves.
    static let gridSize = 3

    /// Phase offsets keep the drifting points out of sync so the motion never looks mechanical.
    private static let centerPhaseOffsets: (x: Float, y: Float) = (0, 1.7)
    private static let bottomPhaseOffset: Float = 3.1

    static func points(at time: TimeInterval) -> [SIMD2<Float>] {
        let phase = Float(time / DesignTokens.Duration.auroraCycle * 2 * .pi)
        let drift: (Float, Float) -> Float = { base, offset in
            base + DesignTokens.Layout.auroraDriftAmplitude * sin(phase + offset)
        }
        return [
            [0, 0], [0.5, 0], [1, 0],
            [0, 0.5], [drift(0.5, centerPhaseOffsets.x), drift(0.5, centerPhaseOffsets.y)], [1, 0.5],
            [0, 1], [drift(0.5, bottomPhaseOffset), 1], [1, 1],
        ]
    }
}

#Preview { AuroraBackground() }
