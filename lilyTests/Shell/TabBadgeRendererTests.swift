import Testing
import UIKit
@testable import lily

@MainActor
struct TabBadgeRendererTests {
    private let renderer = TabBadgeRenderer()

    private func icon(_ count: Int) -> UIImage? {
        renderer.icon(symbol: "message", count: count, glyphColor: .white, badgeColor: .red)
    }

    @Test func zeroOrLessDrawsNoBadge() {
        #expect(icon(0) == nil)
        #expect(icon(-2) == nil)
    }

    @Test func theCountIsCappedLikeTheSystemBadge() {
        #expect(TabBadgeRenderer.label(for: 1) == "1")
        #expect(TabBadgeRenderer.label(for: 99) == "99")
        #expect(TabBadgeRenderer.label(for: 100) == "99+")
        #expect(TabBadgeRenderer.label(for: 5000) == "99+")
    }

    @Test func everySingleDigitWearsTheSameRoundCapsuleAndTheCapOneSize() throws {
        let one = try #require(icon(1))
        let nine = try #require(icon(9))
        #expect(one.size == nine.size, "a single digit's capsule is the circle, whatever the digit")
        let hundred = try #require(icon(100))
        let thousands = try #require(icon(5000))
        #expect(hundred.size == thousands.size, "every capped count reads 99+ and shares one size")
        #expect(hundred.size.width > one.size.width, "three characters need a wider capsule")
    }

    @Test func theCompositeIsCachedPerCountAndNeverTemplated() throws {
        let first = try #require(icon(5))
        #expect(first === icon(5), "the image for a count is rendered once, not per frame")
        #expect(first.renderingMode == .alwaysOriginal, "a template image would tint the badge with the glyph")
    }

    /// The canvas grows by one symmetric inset around the glyph, so the bar, centring the image, keeps the glyph
    /// where the plain template one sits.
    @Test func theCanvasPadsTheGlyphSymmetrically() throws {
        let configuration = UIImage.SymbolConfiguration(pointSize: DesignTokens.TabBar.badgeGlyphPointSize,
                                                        weight: DesignTokens.TabBar.symbolWeight)
        let glyph = try #require(UIImage(systemName: "message", withConfiguration: configuration))
        let badged = try #require(icon(3))
        let grownWidth = badged.size.width - glyph.size.width
        let grownHeight = badged.size.height - glyph.size.height
        #expect(grownWidth > 0 && grownWidth == grownHeight, "the glyph stays centred under the badge")
    }
}
