import Testing
@testable import lily

struct AuroraGeometryTests {
    @Test func pointCountMatchesGrid() {
        #expect(AuroraGeometry.points(at: 0).count == AuroraGeometry.gridSize * AuroraGeometry.gridSize)
    }

    @Test func pointsStayInsideUnitSquare() {
        for t in stride(from: 0.0, through: DesignTokens.Duration.auroraCycle, by: 0.5) {
            for point in AuroraGeometry.points(at: t) {
                #expect(point.x >= 0 && point.x <= 1)
                #expect(point.y >= 0 && point.y <= 1)
            }
        }
    }
}
