import AppKit
import CoreGraphics
import CoreText
import Foundation

// Renders iskra's app icon at 1024x1024 with CoreGraphics (no dependencies): a lowercase "i" set in SF Pro Rounded Black
// in cream on the dark field (ink black with a maroon drift from the top left), its dot a ball with red seams; the
// letter of the name, the ball for the sport. Chosen on 2026-10-09 from a grid of nine typefaces by four colourways on
// the dark field (the user's pick: the rounded face, cream on cream with red seams), after a glowing spark and a flat
// spark (2026-10-08) were rejected. The shipped files are `final-any/dark/tinted.png`, copied into
// `lily/Assets.xcassets/AppIcon.appiconset` as `AppIcon.png`, `AppIcon-Dark.png`, `AppIcon-Tinted.png` (opaque, as the
// App Store requires); `final-layer-*.png` are the same icon as two layers for Icon Composer; `preview-strip.png` shows
// the three appearances at home-screen sizes. The typeface is read from the Mac at render time; the PNGs ship.
// Usage: swift scripts/make-app-icon.swift <output directory>

let size: CGFloat = 1024
let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/icon/out"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

// Brand colours (dark variants of the colorsets) and the cream the letter is set in.
let accent: UInt32 = 0xB72734, inkBlack: UInt32 = 0x0E0407, cream: UInt32 = 0xFFF4EE
let fieldMaroon: UInt32 = 0x3A0617, fieldMid: UInt32 = 0x1E040D
let tintedSeam: UInt32 = 0x8A8A8A

func makeContext(width: CGFloat = size, height: CGFloat = size, opaque: Bool = false) -> CGContext {
    let alpha: CGImageAlphaInfo = opaque ? .noneSkipLast : .premultipliedLast
    return CGContext(data: nil, width: Int(width), height: Int(height), bitsPerComponent: 8, bytesPerRow: 0,
                     space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: alpha.rawValue)!
}

func write(_ context: CGContext, _ name: String) {
    let rep = NSBitmapImageRep(cgImage: context.makeImage()!)
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(outDir)/\(name).png"))
    print("wrote \(name).png")
}

func gradient(_ colors: [CGColor], _ locations: [CGFloat]) -> CGGradient {
    CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!, colors: colors as CFArray, locations: locations)!
}

enum Appearance: String { case any, dark, tinted }

/// The geometry of the icon, shared by the appearances and the layers.
enum Letter {
    /// The stem is the dotless "ı", so the dot can be drawn as a ball; its height on the canvas, and where it sits.
    static let stemHeight: CGFloat = 500
    static let stemCenter = CGPoint(x: 512, y: 350)
    /// The ball's radius follows the stem's width, kept within bounds; the gap is the space between stem and ball.
    static let ballRadiusRange: ClosedRange<CGFloat> = 118...160
    static let ballRadiusPerStemWidth: CGFloat = 0.72
    static let gap: CGFloat = 56
    static let seamWidthPerRadius: CGFloat = 0.17
    static let shadowOffset = CGSize(width: 0, height: -18), shadowBlur: CGFloat = 50
}

/// SF Pro Rounded at the given weight, as CoreText sees it (the system font with the rounded design).
func roundedSystemFont(weight: NSFont.Weight, size pt: CGFloat) -> CTFont {
    let descriptor = NSFont.systemFont(ofSize: pt, weight: weight).fontDescriptor
    return NSFont(descriptor: descriptor.withDesign(.rounded) ?? descriptor, size: pt)! as CTFont
}

/// The outline of one character in `font`, at the origin.
func glyphPath(_ character: Character, _ font: CTFont) -> CGPath {
    let chars = Array(String(character).utf16)
    var glyphs = [CGGlyph](repeating: 0, count: chars.count)
    CTFontGetGlyphsForCharacters(font, chars, &glyphs, chars.count)
    var identity = CGAffineTransform.identity
    return CTFontCreatePathForGlyph(font, glyphs[0], &identity)!
}

/// `path` scaled and moved so its bounding box is centred on `center` with the given height.
func fit(_ path: CGPath, height: CGFloat, center: CGPoint) -> CGPath {
    let box = path.boundingBox
    let scale = height / box.height
    var t = CGAffineTransform(translationX: center.x - box.midX * scale, y: center.y - box.midY * scale).scaledBy(x: scale, y: scale)
    return path.copy(using: &t)!
}

/// The stem on the canvas, and the ball's centre and radius derived from it.
let stemPath = fit(glyphPath("ı", roundedSystemFont(weight: .black, size: 800)), height: Letter.stemHeight, center: Letter.stemCenter)
let ballRadius = min(max(stemPath.boundingBox.width * Letter.ballRadiusPerStemWidth, Letter.ballRadiusRange.lowerBound),
                     Letter.ballRadiusRange.upperBound)
let ballCenter = CGPoint(x: stemPath.boundingBox.midX, y: stemPath.boundingBox.maxY + Letter.gap + ballRadius)

/// The field: ink black with a maroon drift from the top left; the dark appearance drifts less; tinted is plain black.
func drawBackground(_ c: CGContext, appearance: Appearance) {
    let rect = CGRect(x: 0, y: 0, width: size, height: size)
    c.setFillColor(rgb(appearance == .tinted ? 0x000000 : inkBlack)); c.fill(rect)
    guard appearance != .tinted else { return }
    let top: UInt32 = appearance == .dark ? 0x2A0511 : fieldMaroon
    c.drawLinearGradient(gradient([rgb(top), rgb(fieldMid), rgb(inkBlack)], [0, 0.55, 1]),
                         start: CGPoint(x: 0, y: size), end: CGPoint(x: size, y: 0),
                         options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
}

/// A ball: a disc with two seam curves, the tennis-ball reading that stands for any sport.
func drawBall(_ c: CGContext, center p: CGPoint, radius r: CGFloat, fill: CGColor, seam: CGColor) {
    c.saveGState()
    c.setFillColor(fill)
    c.fillEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r))
    c.addEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r)); c.clip()
    c.setStrokeColor(seam); c.setLineWidth(r * Letter.seamWidthPerRadius); c.setLineCap(.round)
    let first = CGMutablePath()
    first.move(to: CGPoint(x: p.x - r * 1.05, y: p.y + r * 0.35))
    first.addQuadCurve(to: CGPoint(x: p.x - r * 0.35, y: p.y - r * 1.05), control: CGPoint(x: p.x + r * 0.15, y: p.y + r * 0.05))
    let second = CGMutablePath()
    second.move(to: CGPoint(x: p.x + r * 1.05, y: p.y - r * 0.35))
    second.addQuadCurve(to: CGPoint(x: p.x + r * 0.35, y: p.y + r * 1.05), control: CGPoint(x: p.x - r * 0.15, y: p.y - r * 0.05))
    c.addPath(first); c.strokePath(); c.addPath(second); c.strokePath()
    c.restoreGState()
}

/// The letter: the stem and the ball, each lifted by a soft shadow; white on black with grey seams when tinted.
func drawLetter(_ c: CGContext, appearance: Appearance) {
    let ink = rgb(appearance == .tinted ? 0xFFFFFF : cream)
    let seam = rgb(appearance == .tinted ? tintedSeam : accent)
    c.saveGState()
    if appearance != .tinted { c.setShadow(offset: Letter.shadowOffset, blur: Letter.shadowBlur, color: rgb(0x000000, 0.5)) }
    c.addPath(stemPath); c.setFillColor(ink); c.fillPath()
    c.restoreGState()
    c.saveGState()
    if appearance != .tinted { c.setShadow(offset: Letter.shadowOffset, blur: Letter.shadowBlur, color: rgb(0x000000, 0.5)) }
    drawBall(c, center: ballCenter, radius: ballRadius, fill: ink, seam: seam)
    c.restoreGState()
}

func drawIcon(_ appearance: Appearance, opaque: Bool) -> CGContext {
    let c = makeContext(opaque: opaque)
    drawBackground(c, appearance: appearance)
    drawLetter(c, appearance: appearance)
    return c
}

// The final set, opaque, one per appearance.
var finals: [CGImage] = []
for appearance in [Appearance.any, .dark, .tinted] {
    let c = drawIcon(appearance, opaque: true)
    write(c, "final-\(appearance.rawValue)")
    finals.append(c.makeImage()!)
}

// Layers for Icon Composer: the background alone and the letter alone (transparent).
do {
    let b = makeContext(); drawBackground(b, appearance: .any); write(b, "final-layer-background")
    let l = makeContext(); drawLetter(l, appearance: .any); write(l, "final-layer-letter")
}

// The three appearances at 180 px (3x) and 60 px with the iOS corner radius, as a home screen would show them.
let preview = makeContext(width: 3 * 260, height: 420)
preview.setFillColor(rgb(0x1C1C1E)); preview.fill(CGRect(x: 0, y: 0, width: 3 * 260, height: 420))
for (index, image) in finals.enumerated() {
    let big = CGRect(x: 40 + CGFloat(index) * 260, y: 180, width: 180, height: 180)
    let small = CGRect(x: 100 + CGFloat(index) * 260, y: 60, width: 60, height: 60)
    for rect in [big, small] {
        preview.saveGState()
        preview.addPath(CGPath(roundedRect: rect, cornerWidth: rect.width * 0.2237, cornerHeight: rect.width * 0.2237, transform: nil))
        preview.clip()
        preview.interpolationQuality = .high
        preview.draw(image, in: rect)
        preview.restoreGState()
    }
}
write(preview, "preview-strip")
