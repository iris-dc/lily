import AppKit
import CoreGraphics
import CoreImage
import CoreText
import Foundation

// Renders iskra's app icon at 1024x1024 with CoreGraphics and CoreImage's Gaussian blur (no dependencies): a lowercase "i"
// whose stem is a drawn rounded rectangle (nine tenths the width of SF Pro Rounded Heavy's "ı", corners at 42 % of
// the width, so it reads a shade slimmer and squarer than the type) and whose dot is a ball with red seams, both
// shaded cream to rose and drawn at 85 % so the glow shows through, centred on a warm graphite field with the accent
// red glowing out of the letter into it. The shipped files are `final-any/dark/tinted.png`, copied into
// `lily/Assets.xcassets/AppIcon.appiconset` as `AppIcon.png`, `AppIcon-Dark.png`, `AppIcon-Tinted.png` (opaque, as the
// App Store requires); `final-layer-*.png` are the same icon as two layers for Icon Composer (the field with its glow,
// and the letter); `preview-strip.png` shows the three appearances at home-screen sizes. The typeface is read from the
// Mac at render time (for the stem's reference width); the PNGs ship.
// Usage: swift scripts/make-app-icon.swift <output directory>

let size: CGFloat = 1024
let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/icon/out"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let canvas = CGRect(x: 0, y: 0, width: size, height: size)

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

// Brand colours: the accent, the letter's cream and the rose it shades into, and the warm graphite of the field.
let accent: UInt32 = 0xB72734
let letterTop: UInt32 = 0xFFF7F2, letterBottom: UInt32 = 0xF2B8BE
let fieldTop: UInt32 = 0x2A2224, fieldBottom: UInt32 = 0x161112
let darkFieldTop: UInt32 = 0x221B1D, darkFieldBottom: UInt32 = 0x100C0D
let tintedSeam: UInt32 = 0x8A8A8A

func makeContext(width: CGFloat = size, height: CGFloat = size, opaque: Bool = false) -> CGContext {
    let alpha: CGImageAlphaInfo = opaque ? .noneSkipLast : .premultipliedLast
    return CGContext(data: nil, width: Int(width), height: Int(height), bitsPerComponent: 8, bytesPerRow: 0,
                     space: space, bitmapInfo: alpha.rawValue)!
}

func write(_ context: CGContext, _ name: String) {
    let rep = NSBitmapImageRep(cgImage: context.makeImage()!)
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(outDir)/\(name).png"))
    print("wrote \(name).png")
}

func gradient(_ colors: [CGColor], _ locations: [CGFloat]) -> CGGradient {
    CGGradient(colorsSpace: space, colors: colors as CFArray, locations: locations)!
}

enum Appearance: String { case any, dark, tinted }

/// The letter's geometry and finish, shared by the appearances and the layers.
enum Letter {
    /// The stem's height, its width as a fraction of SF Pro Rounded Heavy's "ı" at that height, and its corner radius
    /// as a fraction of its width (the type's own is one half).
    static let stemHeight: CGFloat = 500
    static let stemWidthPerGlyph: CGFloat = 0.90
    static let cornerPerWidth: CGFloat = 0.42
    /// The ball's radius per stem width, and the gap between stem and ball.
    static let ballRadiusPerStemWidth: CGFloat = 0.64
    static let gap: CGFloat = 56
    static let seamWidthPerRadius: CGFloat = 0.17
    static let opacity: CGFloat = 0.85
    static let shadowOffset = CGSize(width: 0, height: -14), shadowBlur: CGFloat = 40, shadowAlpha: CGFloat = 0.55
}

/// The glow: the accent blurred out of the letter's own shape, a tight bright one over a wide faint one.
enum Glow {
    static let blur: CGFloat = 70, alpha: CGFloat = 0.85
    static let haloBlur: CGFloat = 220, haloAlpha: CGFloat = 0.7
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

/// The stem's width: a fraction of the type's, so the letter keeps the type's proportions while reading slimmer.
let stemWidth: CGFloat = {
    let glyph = glyphPath("ı", roundedSystemFont(weight: .heavy, size: 800)).boundingBox
    return glyph.width * (Letter.stemHeight / glyph.height) * Letter.stemWidthPerGlyph
}()
let ballRadius = stemWidth * Letter.ballRadiusPerStemWidth
/// The stem and the ball, the whole letter centred on the canvas from the foot of the stem to the top of the ball.
let stemRect: CGRect = {
    let letterHeight = Letter.stemHeight + Letter.gap + 2 * ballRadius
    return CGRect(x: (size - stemWidth) / 2, y: (size - letterHeight) / 2, width: stemWidth, height: Letter.stemHeight)
}()
let stemPath = CGPath(roundedRect: stemRect, cornerWidth: stemWidth * Letter.cornerPerWidth,
                      cornerHeight: stemWidth * Letter.cornerPerWidth, transform: nil)
let ballCenter = CGPoint(x: stemRect.midX, y: stemRect.maxY + Letter.gap + ballRadius)
let ballRect = CGRect(x: ballCenter.x - ballRadius, y: ballCenter.y - ballRadius, width: 2 * ballRadius, height: 2 * ballRadius)
let letterPath: CGPath = { let p = CGMutablePath(); p.addPath(stemPath); p.addEllipse(in: ballRect); return p }()

/// `path` filled with `color` and blurred by `radius`, on a transparent canvas.
func blurred(_ path: CGPath, color: CGColor, radius: CGFloat) -> CGImage {
    let c = makeContext()
    c.setFillColor(color); c.addPath(path); c.fillPath()
    let blur = CIFilter(name: "CIGaussianBlur")!
    blur.setValue(CIImage(cgImage: c.makeImage()!), forKey: kCIInputImageKey)
    blur.setValue(radius, forKey: kCIInputRadiusKey)
    let output = blur.outputImage!.cropped(to: canvas)
    return CIContext(options: [.workingColorSpace: space]).createCGImage(output, from: output.extent)!
}

/// The field: warm graphite, lighter at the top, with the accent glowing out of the letter; the dark appearance a shade
/// darker; tinted is plain black without a glow, since the system paints it in one colour.
func drawBackground(_ c: CGContext, appearance: Appearance) {
    guard appearance != .tinted else { c.setFillColor(rgb(0x000000)); c.fill(canvas); return }
    let (top, bottom) = appearance == .dark ? (darkFieldTop, darkFieldBottom) : (fieldTop, fieldBottom)
    c.drawLinearGradient(gradient([rgb(top), rgb(bottom)], [0, 1]),
                         start: CGPoint(x: 0, y: size), end: CGPoint(x: 0, y: 0), options: [])
    for (blur, alpha) in [(Glow.haloBlur, Glow.haloAlpha), (Glow.blur, Glow.alpha)] {
        c.saveGState(); c.setAlpha(alpha)
        c.draw(blurred(letterPath, color: rgb(accent), radius: blur), in: canvas)
        c.restoreGState()
    }
}

/// The two seam curves on the ball, the tennis-ball reading that stands for any sport.
func drawSeams(_ c: CGContext, seam: CGColor) {
    let p = ballCenter, r = ballRadius
    c.saveGState()
    c.addEllipse(in: ballRect); c.clip()
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

/// The letter: stem and ball seated by one soft shadow, shaded cream to rose from the ball down, drawn at 85 % so the
/// glow warms it; white on black with grey seams and opaque when tinted.
func drawLetter(_ c: CGContext, appearance: Appearance) {
    let tinted = appearance == .tinted
    c.saveGState()
    c.setAlpha(tinted ? 1 : Letter.opacity)
    c.beginTransparencyLayer(auxiliaryInfo: nil)
    // The flat fill is what casts the shadow: a gradient drawn inside a clip casts none.
    c.saveGState()
    if !tinted { c.setShadow(offset: Letter.shadowOffset, blur: Letter.shadowBlur, color: rgb(0x000000, Letter.shadowAlpha)) }
    c.setFillColor(rgb(tinted ? 0xFFFFFF : letterTop)); c.addPath(letterPath); c.fillPath()
    c.restoreGState()
    if !tinted {
        c.saveGState()
        c.addPath(letterPath); c.clip()
        c.drawLinearGradient(gradient([rgb(letterTop), rgb(letterBottom)], [0, 1]),
                             start: CGPoint(x: 0, y: ballRect.maxY), end: CGPoint(x: 0, y: stemRect.minY), options: [])
        c.restoreGState()
    }
    drawSeams(c, seam: rgb(tinted ? tintedSeam : accent))
    c.endTransparencyLayer()
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

// Layers for Icon Composer: the field with its glow, and the letter alone (transparent).
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
