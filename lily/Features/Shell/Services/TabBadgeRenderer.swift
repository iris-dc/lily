import UIKit

/// Draws the Chats tab's unread count. The iOS 26 floating bar honours only a label's title and `UIImage` and never
/// moves its own badge (`badgePositionAdjustment` probed at zero effect), so the count the owner wants closer to the
/// glyph is drawn by hand, every metric and offset in `DesignTokens.TabBar`. Two renders share one capsule drawing:
/// `capsule(count:badgeColor:)`, the capsule alone for `TabBarBadgeOverlay` to mount inside each item tree's
/// Chats item (every treatment the glyph gets — the collapse morph, a selection crossfade, the lens copy —
/// carries it, where a composited image could only swap), and
/// `icon(...)`, the glyph with the capsule composited over its top-right corner — the fallback when the overlay
/// finds no whole item trees to ride (regular widths, a lost hierarchy signal). The composite renders as `.alwaysOriginal` — the bar cannot tint it — so the caller passes the
/// glyph's colour per selection state; images are cached per count and colour, never re-rendered per frame.
final class TabBadgeRenderer {
    private struct Key: Hashable {
        let symbol: String
        let text: String
        let glyphColor: UIColor
        let badgeColor: UIColor
    }

    private struct CapsuleKey: Hashable {
        let text: String
        let badgeColor: UIColor
    }

    private var cache: [Key: UIImage] = [:]
    private var capsuleCache: [CapsuleKey: UIImage] = [:]

    /// What the badge reads: the count, capped like the system badge.
    static func label(for count: Int) -> String {
        count > DesignTokens.TabBar.badgeCountCap ? "\(DesignTokens.TabBar.badgeCountCap)+" : "\(count)"
    }

    /// The glyph with the count over its top-right corner, or nothing at zero — the plain template label is right then.
    func icon(symbol: String, count: Int, glyphColor: UIColor, badgeColor: UIColor) -> UIImage? {
        guard count > 0 else { return nil }
        let key = Key(symbol: symbol, text: Self.label(for: count), glyphColor: glyphColor, badgeColor: badgeColor)
        if let cached = cache[key] { return cached }
        let image = composite(for: key)
        cache[key] = image
        return image
    }

    /// The capsule alone at its natural size, for the overlay riding the bar; nothing at zero — the overlay hides then.
    func capsule(count: Int, badgeColor: UIColor) -> UIImage? {
        guard count > 0 else { return nil }
        let key = CapsuleKey(text: Self.label(for: count), badgeColor: badgeColor)
        if let cached = capsuleCache[key] { return cached }
        let size = badgeSize(for: key.text)
        let image = UIGraphicsImageRenderer(size: size).image { _ in
            drawCapsule(text: key.text as NSString, color: key.badgeColor, in: CGRect(origin: .zero, size: size))
        }
        capsuleCache[key] = image
        return image
    }

    /// The glyph as the composite draws it (`badgeGlyphPointSize`): the box the owner tuned the capsule offset
    /// against, which the overlay anchors its capsule on around the glyph view's centre.
    static func glyphSize(symbol: String) -> CGSize {
        drawnGlyph(symbol: symbol).size
    }

    private static func drawnGlyph(symbol: String) -> UIImage {
        let configuration = UIImage.SymbolConfiguration(pointSize: DesignTokens.TabBar.badgeGlyphPointSize,
                                                        weight: DesignTokens.TabBar.symbolWeight)
        return UIImage(systemName: symbol, withConfiguration: configuration) ?? UIImage()
    }

    /// The composite's symmetric inset around the glyph: the capsule's overhang past the glyph's corner, which the
    /// canvas grows by on every side so the bar, centring the image, keeps the glyph where the template one sits.
    private func glyphInset(forText text: String) -> CGFloat {
        let badge = badgeSize(for: text)
        let offset = DesignTokens.TabBar.badgeCenterOffset
        return ceil(max(offset.x + badge.width / 2, badge.height / 2 - offset.y, 0))
    }

    /// The glyph centred on a canvas grown by `glyphInset`, the capsule's centre `badgeCenterOffset` from the
    /// glyph's top-right corner.
    private func composite(for key: Key) -> UIImage {
        let glyph = Self.drawnGlyph(symbol: key.symbol)
            .withTintColor(key.glyphColor, renderingMode: .alwaysOriginal)
        let badge = badgeSize(for: key.text)
        let offset = DesignTokens.TabBar.badgeCenterOffset
        let inset = glyphInset(forText: key.text)
        let canvas = CGSize(width: glyph.size.width + inset * 2, height: glyph.size.height + inset * 2)
        let capsule = CGRect(x: inset + glyph.size.width + offset.x - badge.width / 2,
                             y: inset + offset.y - badge.height / 2,
                             width: badge.width,
                             height: badge.height)
        let image = UIGraphicsImageRenderer(size: canvas).image { _ in
            glyph.draw(at: CGPoint(x: inset, y: inset))
            drawCapsule(text: key.text as NSString, color: key.badgeColor, in: capsule)
        }
        return image.withRenderingMode(.alwaysOriginal)
    }

    /// One capsule drawing for both renders, so the overlay's capsule is the composite's to the pixel.
    private func drawCapsule(text: NSString, color: UIColor, in rect: CGRect) {
        color.setFill()
        UIBezierPath(roundedRect: rect, cornerRadius: rect.height / 2).fill()
        let attributes = textAttributes
        let size = text.size(withAttributes: attributes)
        text.draw(at: CGPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2),
                  withAttributes: attributes)
    }

    /// The capsule around the count: never narrower than it is tall, so a single digit reads as a circle.
    private func badgeSize(for text: String) -> CGSize {
        let width = (text as NSString).size(withAttributes: textAttributes).width
            + DesignTokens.TabBar.badgeHorizontalPadding * 2
        return CGSize(width: max(DesignTokens.TabBar.badgeHeight, width), height: DesignTokens.TabBar.badgeHeight)
    }

    /// White SF Rounded close to the system badge's own type.
    private var textAttributes: [NSAttributedString.Key: Any] {
        let size = DesignTokens.TabBar.badgeFontSize
        let base = UIFont.systemFont(ofSize: size, weight: .medium)
        let font = base.fontDescriptor.withDesign(.rounded).map { UIFont(descriptor: $0, size: size) } ?? base
        return [.font: font, .foregroundColor: DesignTokens.TabBar.badgeTextColor]
    }
}
