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
        #expect(hundred.size == one.size, "a wider capsule grows leftward over the glyph; the canvas never grows")
    }

    /// The minimized iOS 26 bar draws the composite unscaled, centred in its circle (measured on the simulator), so
    /// everything drawn must stay inside `minimizedCircleRadius`, with `minimizedCircleClearance` of air to the rim.
    @Test func everyCountStaysInsideTheMinimizedBarsCircle() throws {
        let bound = DesignTokens.TabBar.minimizedCircleRadius - DesignTokens.TabBar.minimizedCircleClearance
        for count in [1, 23, 100] {
            let image = try #require(icon(count))
            let reach = try #require(Self.farthestDrawnPoint(of: image))
            #expect(reach <= bound, "count \(count) reaches \(reach) pt from the centre, out of the minimized circle")
        }
    }

    /// The farthest drawn pixel's distance from the image's centre, in points.
    private static func farthestDrawnPoint(of image: UIImage) -> CGFloat? {
        guard let cgImage = image.cgImage else { return nil }
        let width = cgImage.width
        let height = cgImage.height
        var alphas = [UInt8](repeating: 0, count: width * height)
        // The context writes through the buffer's pointer, so it must not outlive the closure the pointer is valid in.
        let rendered = alphas.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress,
                                          width: width,
                                          height: height,
                                          bitsPerComponent: 8,
                                          bytesPerRow: width,
                                          space: CGColorSpaceCreateDeviceGray(),
                                          bitmapInfo: CGImageAlphaInfo.alphaOnly.rawValue) else { return false }
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard rendered else { return nil }
        var farthest: CGFloat = 0
        for y in 0..<height {
            for x in 0..<width where alphas[y * width + x] > 25 {
                let dx = CGFloat(x) + 0.5 - CGFloat(width) / 2
                let dy = CGFloat(y) + 0.5 - CGFloat(height) / 2
                farthest = max(farthest, (dx * dx + dy * dy).squareRoot())
            }
        }
        return farthest / image.scale
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
