import UIKit

/// Draws the Chats tab's unread count into the tab's glyph image. The iOS 26 floating bar honours only a label's
/// title and `UIImage` and never moves its own badge (`badgePositionAdjustment` probed at zero effect, 2026-11-12),
/// so the count the owner wants closer to the glyph rides the image itself: the glyph with an accent capsule and the
/// white count over its top-right corner, every metric and offset in `DesignTokens.TabBar`. The composite renders as
/// `.alwaysOriginal` — the bar cannot tint it — so the caller passes the glyph's colour per selection state; images
/// are cached per count and colour (at most the capped counts times the two states), never re-rendered per frame.
final class TabBadgeRenderer {
    private struct Key: Hashable {
        let symbol: String
        let text: String
        let glyphColor: UIColor
        let badgeColor: UIColor
    }

    private var cache: [Key: UIImage] = [:]

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

    /// The glyph centred on a canvas grown by one symmetric inset covering the capsule's overhang (the bar centres
    /// the image, so the glyph stays where the template one sits). The single-digit capsule's centre sits
    /// `badgeCenterOffset` from the glyph's top-right corner; a wider count keeps that capsule's right edge and grows
    /// leftward over the glyph, like the system badge, so no count reaches further out — the minimized bar draws the
    /// bitmap unscaled inside its small circle, and the capsule must stay inside it.
    private func composite(for key: Key) -> UIImage {
        let configuration = UIImage.SymbolConfiguration(pointSize: DesignTokens.TabBar.badgeGlyphPointSize,
                                                        weight: DesignTokens.TabBar.symbolWeight)
        let glyph = (UIImage(systemName: key.symbol, withConfiguration: configuration) ?? UIImage())
            .withTintColor(key.glyphColor, renderingMode: .alwaysOriginal)
        let badge = badgeSize(for: key.text)
        let offset = DesignTokens.TabBar.badgeCenterOffset
        let rightReach = offset.x + DesignTokens.TabBar.badgeHeight / 2
        let inset = ceil(max(rightReach,
                             badge.height / 2 - offset.y,
                             badge.width - rightReach - glyph.size.width,
                             0))
        // Every count shares one canvas only while the single-digit reaches dominate the inset: the widest capsule
        // must not out-grow them, or counts would render at different sizes and the minimized-circle fit would drift.
        assert(badge.width - rightReach - glyph.size.width <= max(rightReach, badge.height / 2 - offset.y),
               "the capsule for \(key.text) outgrows the shared canvas; revisit the TabBar badge tokens")
        let canvas = CGSize(width: glyph.size.width + inset * 2, height: glyph.size.height + inset * 2)
        let capsule = CGRect(x: inset + glyph.size.width + rightReach - badge.width,
                             y: inset + offset.y - badge.height / 2,
                             width: badge.width,
                             height: badge.height)
        let image = UIGraphicsImageRenderer(size: canvas).image { _ in
            glyph.draw(at: CGPoint(x: inset, y: inset))
            key.badgeColor.setFill()
            UIBezierPath(roundedRect: capsule, cornerRadius: badge.height / 2).fill()
            let text = key.text as NSString
            let attributes = textAttributes
            let size = text.size(withAttributes: attributes)
            text.draw(at: CGPoint(x: capsule.midX - size.width / 2, y: capsule.midY - size.height / 2),
                      withAttributes: attributes)
        }
        return image.withRenderingMode(.alwaysOriginal)
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
