import Foundation
import Testing
@testable import lily

struct AuroraGeometryTests {
    /// Long enough to cover every drift period several times over.
    private let sampleWindow: TimeInterval = 600
    private let sampleStep: TimeInterval = 0.7
    private let cornerIndices = [0, 3, 12, 15]

    @Test func pointCountMatchesGrid() {
        #expect(AuroraGeometry.points(at: 0).count == AuroraGeometry.gridSize * AuroraGeometry.gridSize)
    }

    @Test func pointsStayInsideUnitSquare() {
        for t in stride(from: 0.0, through: sampleWindow, by: sampleStep) {
            for point in AuroraGeometry.points(at: t) {
                #expect(point.x >= 0 && point.x <= 1)
                #expect(point.y >= 0 && point.y <= 1)
            }
        }
    }

    @Test func cornersStayPinned() {
        let corners: [SIMD2<Float>] = [[0, 0], [1, 0], [0, 1], [1, 1]]
        for t in stride(from: 0.0, through: sampleWindow, by: sampleStep) {
            let points = AuroraGeometry.points(at: t)
            for (index, expected) in zip(cornerIndices, corners) {
                #expect(points[index] == expected)
            }
        }
    }

    @Test func edgePointsStayOnTheirEdge() {
        for t in stride(from: 0.0, through: sampleWindow, by: sampleStep) {
            let points = AuroraGeometry.points(at: t)
            #expect(points[1].y == 0 && points[2].y == 0)
            #expect(points[13].y == 1 && points[14].y == 1)
            #expect(points[4].x == 0 && points[8].x == 0)
            #expect(points[7].x == 1 && points[11].x == 1)
        }
    }

    @Test func interiorPointsKeepTheirOrder() {
        for t in stride(from: 0.0, through: sampleWindow, by: sampleStep) {
            let points = AuroraGeometry.points(at: t)
            #expect(points[5].x < points[6].x && points[9].x < points[10].x)
            #expect(points[5].y < points[9].y && points[6].y < points[10].y)
        }
    }

    @Test func meshMovesBetweenNearbyFrames() {
        #expect(AuroraGeometry.points(at: 0) != AuroraGeometry.points(at: 1))
    }

    /// Regression: the phase must be reduced in `Double`, otherwise a wall-clock time cast to `Float` freezes the drift.
    @Test func meshStillMovesAtWallClockMagnitudes() {
        let now: TimeInterval = 800_000_000
        #expect(AuroraGeometry.points(at: now) != AuroraGeometry.points(at: now + 0.5))
    }

    @Test func angleIsContinuousAcrossPeriodBoundary() {
        let period = DesignTokens.Aurora.driftPeriods[0]
        let justBefore = sin(AuroraGeometry.angle(at: period - 0.001, period: period))
        let justAfter = sin(AuroraGeometry.angle(at: period + 0.001, period: period))
        #expect(abs(justBefore - justAfter) < 0.01)
    }

    @Test func coreGlowStaysWithinSwing() {
        let swing = DesignTokens.Aurora.glowSwing
        for t in stride(from: 0.0, through: sampleWindow, by: sampleStep) {
            let glow = AuroraGeometry.coreGlow(at: t)
            #expect(glow >= 1 - swing - 0.0001 && glow <= 1 + swing + 0.0001)
        }
    }

    @Test func cellIntensitiesCoverEveryCellAndStayWithinTheirSwing() {
        let swing = DesignTokens.Aurora.rippleSwing + DesignTokens.Aurora.rippleCrossSwing
        let ceiling = (1 + swing) * (1 + DesignTokens.Aurora.glowSwing) + 0.0001
        let floor = (1 - swing) * (1 - DesignTokens.Aurora.glowSwing) - 0.0001
        for t in stride(from: 0.0, through: sampleWindow, by: sampleStep) {
            let intensities = AuroraGeometry.cellIntensities(at: t)
            #expect(intensities.count == AuroraGeometry.gridSize * AuroraGeometry.gridSize)
            #expect(intensities.allSatisfy { $0 >= floor && $0 <= ceiling })
        }
    }

    /// The ripple is what makes the red visibly flow: neighbouring cells must not brighten in lockstep.
    @Test func rippleTravelsAcrossCells() {
        let now: TimeInterval = 800_000_000
        let intensities = AuroraGeometry.cellIntensities(at: now)
        #expect(Set(intensities.map { ($0 * 1000).rounded() }).count > 1)
        #expect(intensities != AuroraGeometry.cellIntensities(at: now + 0.5))
    }

    /// The drift amplitude token is only exact if the summed sine weights add up to one.
    @Test func driftWeightsSumToOne() {
        #expect(abs(DesignTokens.Aurora.driftWeights.reduce(0, +) - 1) < 0.0001)
        #expect(DesignTokens.Aurora.driftWeights.count <= DesignTokens.Aurora.driftPeriods.count)
    }

    @Test func paletteHasOneRolePerMeshPoint() {
        #expect(AuroraPalette.roles.count == AuroraGeometry.gridSize * AuroraGeometry.gridSize)
        #expect(AuroraPalette.roles.filter { $0 == .core }.count == 1)
        #expect(AuroraPalette.roles.filter { $0 == .ember }.count == 1)
    }
}
