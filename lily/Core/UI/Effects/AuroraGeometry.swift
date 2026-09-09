import Foundation

/// Pure geometry for the ember mesh so it can be unit tested and stays out of the view.
///
/// The mesh is 4x4. Corners are pinned, edge points slide along their edge, and the four interior
/// points roam on Lissajous paths: each axis sums three sines drawn from four incommensurate periods,
/// with a per-point phase offset, so the drift wanders without ever visibly looping.
nonisolated enum AuroraGeometry {
    static let gridSize = 4
    private static let lastIndex = gridSize - 1
    private static let periods = DesignTokens.Aurora.driftPeriods

    /// Golden angle in radians; spreading phases by it keeps every point out of step with every other.
    private static let goldenAngle: Float = .pi * (3 - Float(5).squareRoot())

    /// Row-major mesh points for `MeshGradient`, all inside the unit square.
    static func points(at time: TimeInterval) -> [SIMD2<Float>] {
        let angles = periods.map { angle(at: time, period: $0) }
        return (0..<gridSize * gridSize).map { index in
            point(row: index / gridSize, column: index % gridSize, angles: angles)
        }
    }

    /// Breathing factor for the core color's opacity: `1 ± glowSwing` on its own slow period.
    static func coreGlow(at time: TimeInterval) -> Double {
        1 + DesignTokens.Aurora.glowSwing * sin(reducedPhase(at: time, period: DesignTokens.Aurora.glowPeriod))
    }

    /// Row-major opacity multipliers for every mesh cell: one brightness wave travels down the main diagonal and
    /// a weaker, slower one across the other, so the red flows without a regular beat; the core breathes on top.
    static func cellIntensities(at time: TimeInterval) -> [Double] {
        let tokens = DesignTokens.Aurora.self
        let mainPhase = reducedPhase(at: time, period: tokens.ripplePeriod)
        let crossPhase = reducedPhase(at: time, period: tokens.rippleCrossPeriod)
        let breath = coreGlow(at: time)
        return (0..<gridSize * gridSize).map { index in
            let row = Double(index / gridSize)
            let column = Double(index % gridSize)
            let ripple = 1 + tokens.rippleSwing * sin(mainPhase - (row + column) * tokens.rippleSpacing)
                + tokens.rippleCrossSwing * sin(crossPhase - (row - column) * tokens.rippleSpacing)
            return AuroraPalette.roles[index] == .core ? ripple * breath : ripple
        }
    }

    /// Phase in radians, reduced to one period *before* leaving `Double`.
    ///
    /// `Date.timeIntervalSinceReferenceDate` is around 8e8 s. A phase computed from it in `Float` lands near
    /// 1e8-3e8, where one `Float` step is 8-32 rad, so `sin` would hold still for a minute and then snap.
    static func angle(at time: TimeInterval, period: TimeInterval) -> Float {
        Float(reducedPhase(at: time, period: period))
    }

    private static func reducedPhase(at time: TimeInterval, period: TimeInterval) -> Double {
        time.truncatingRemainder(dividingBy: period) / period * 2 * .pi
    }

    private static func point(row: Int, column: Int, angles: [Float]) -> SIMD2<Float> {
        let base = SIMD2<Float>(Float(column) / Float(lastIndex), Float(row) / Float(lastIndex))
        let index = row * gridSize + column
        let phase = Float(index) * goldenAngle
        let offset = SIMD2<Float>(
            wave(angles, primary: index % angles.count, phase: phase),
            wave(angles, primary: (index + 1) % angles.count, phase: phase + .pi / 2)
        )
        return base + driftAmplitude(row: row, column: column) * offset
    }

    /// Corners are pinned, edge points move only along their edge, interior points move on both axes.
    private static func driftAmplitude(row: Int, column: Int) -> SIMD2<Float> {
        let onVerticalEdge = column == 0 || column == lastIndex
        let onHorizontalEdge = row == 0 || row == lastIndex
        switch (onVerticalEdge, onHorizontalEdge) {
        case (true, true): return .zero
        case (true, false): return SIMD2(0, DesignTokens.Aurora.edgeDriftAmplitude)
        case (false, true): return SIMD2(DesignTokens.Aurora.edgeDriftAmplitude, 0)
        case (false, false): return SIMD2(repeating: DesignTokens.Aurora.driftAmplitude)
        }
    }

    /// Several sines with different periods per axis, each with its own phase; the weights sum to one so
    /// the amplitude stays bounded while the path never settles into a visible loop.
    private static func wave(_ angles: [Float], primary: Int, phase: Float) -> Float {
        DesignTokens.Aurora.driftWeights.enumerated().reduce(0) { sum, term in
            let (rank, weight) = term
            let angle = angles[(primary + rank) % angles.count]
            return sum + weight * sin(angle + phase * Float(rank + 1))
        }
    }
}
