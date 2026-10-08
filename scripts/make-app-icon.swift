import AppKit
import CoreGraphics
import CoreText
import Foundation

// Renders iskra's app icon at 1024x1024 with CoreGraphics (no dependencies): a spark glyph in the brand red on the dark
// aurora with one amber glint. The shipped files are `final-any/dark/tinted.png`, copied into
// `lily/Assets.xcassets/AppIcon.appiconset` as `AppIcon.png`, `AppIcon-Dark.png`, `AppIcon-Tinted.png` (opaque, as the
// App Store requires); `final-layer-*.png` are the same icon as three layers for Icon Composer. The other outputs are
// the candidates judged on 2026-10-08 (A spark, B the "i" with a spark dot, C an ember) and a home-screen-size strip.
// Usage: swift scripts/make-app-icon.swift <output directory>

let size: CGFloat = 1024
let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/icon/out"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

// Brand colours (dark variants of the colorsets).
let accent: UInt32 = 0xB72734, maroon: UInt32 = 0x5E0C26, raspberry: UInt32 = 0xB31B3F, amber: UInt32 = 0xC98A12, amberLight: UInt32 = 0xF2B544
let inkBlack: UInt32 = 0x0E0407

func makeContext(opaque: Bool = false) -> CGContext {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let alpha: CGImageAlphaInfo = opaque ? .noneSkipLast : .premultipliedLast
    return CGContext(data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8, bytesPerRow: 0,
                     space: space, bitmapInfo: alpha.rawValue)!
}

func write(_ context: CGContext, _ name: String) {
    let image = context.makeImage()!
    let rep = NSBitmapImageRep(cgImage: image)
    let data = rep.representation(using: .png, properties: [:])!
    try! data.write(to: URL(fileURLWithPath: "\(outDir)/\(name).png"))
    print("wrote \(name).png")
}

func gradient(_ colors: [CGColor], _ locations: [CGFloat]) -> CGGradient {
    CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!, colors: colors as CFArray, locations: locations)!
}

enum Appearance: String { case any, dark, tinted }

/// The aurora: a diagonal maroon-to-black field with a raspberry glow top-left and a faint amber breath bottom-right.
func drawBackground(_ c: CGContext, appearance: Appearance) {
    let rect = CGRect(x: 0, y: 0, width: size, height: size)
    switch appearance {
    case .tinted:
        c.setFillColor(rgb(0x000000)); c.fill(rect)
    case .any, .dark:
        let top: UInt32 = appearance == .dark ? 0x3A0617 : maroon
        c.drawLinearGradient(gradient([rgb(top), rgb(0x2A0510), rgb(inkBlack)], [0, 0.45, 1]),
                             start: CGPoint(x: 0, y: size), end: CGPoint(x: size, y: 0), options: [])
        c.drawRadialGradient(gradient([rgb(raspberry, appearance == .dark ? 0.45 : 0.6), rgb(raspberry, 0)], [0, 1]),
                             startCenter: CGPoint(x: 230, y: 820), startRadius: 0,
                             endCenter: CGPoint(x: 230, y: 820), endRadius: 720, options: [])
        c.drawRadialGradient(gradient([rgb(amber, 0.16), rgb(amber, 0)], [0, 1]),
                             startCenter: CGPoint(x: 900, y: 120), startRadius: 0,
                             endCenter: CGPoint(x: 900, y: 120), endRadius: 520, options: [])
    }
}

/// A four-point spark: arms of the given lengths, sides pulled towards the centre so the arms taper to points.
func sparkPath(center: CGPoint, top: CGFloat, right: CGFloat, bottom: CGFloat, left: CGFloat, pinch: CGFloat) -> CGPath {
    let p = CGMutablePath()
    let t = CGPoint(x: center.x, y: center.y + top), r = CGPoint(x: center.x + right, y: center.y)
    let b = CGPoint(x: center.x, y: center.y - bottom), l = CGPoint(x: center.x - left, y: center.y)
    p.move(to: t)
    p.addQuadCurve(to: r, control: CGPoint(x: center.x + pinch, y: center.y + pinch))
    p.addQuadCurve(to: b, control: CGPoint(x: center.x + pinch, y: center.y - pinch))
    p.addQuadCurve(to: l, control: CGPoint(x: center.x - pinch, y: center.y - pinch))
    p.addQuadCurve(to: t, control: CGPoint(x: center.x - pinch, y: center.y + pinch))
    p.closeSubpath()
    return p
}

func fillGlyph(_ c: CGContext, path: CGPath, appearance: Appearance, glow: Bool) {
    c.saveGState()
    if glow && appearance != .tinted {
        c.setShadow(offset: .zero, blur: 70, color: rgb(raspberry, 0.75))
        c.addPath(path); c.setFillColor(rgb(accent)); c.fillPath()
        c.setShadow(offset: .zero, blur: 0, color: nil)
    }
    c.addPath(path); c.clip()
    let box = path.boundingBox
    let colors: [CGColor] = appearance == .tinted
        ? [rgb(0xFFFFFF), rgb(0xBDBDBD)]
        : [rgb(0xE24B55), rgb(accent), rgb(0x8F1526)]
    let locations: [CGFloat] = appearance == .tinted ? [0, 1] : [0, 0.55, 1]
    c.drawLinearGradient(gradient(colors, locations),
                         start: CGPoint(x: box.midX, y: box.maxY), end: CGPoint(x: box.midX, y: box.minY), options: [])
    if appearance != .tinted {
        // A soft specular at the upper left of the glyph, the way glass catches the aurora.
        c.drawRadialGradient(gradient([rgb(0xFFFFFF, 0.28), rgb(0xFFFFFF, 0)], [0, 1]),
                             startCenter: CGPoint(x: box.midX - box.width * 0.18, y: box.maxY - box.height * 0.22),
                             startRadius: 0, endCenter: CGPoint(x: box.midX - box.width * 0.18, y: box.maxY - box.height * 0.22),
                             endRadius: box.width * 0.55, options: [])
    }
    c.restoreGState()
}

/// The amber glint: a small symmetrical spark with a white core, the one touch of the secondary colour.
func drawGlint(_ c: CGContext, at center: CGPoint, arm: CGFloat, appearance: Appearance) {
    let path = sparkPath(center: center, top: arm, right: arm, bottom: arm, left: arm, pinch: arm * 0.16)
    c.saveGState()
    if appearance != .tinted { c.setShadow(offset: .zero, blur: arm * 0.6, color: rgb(amberLight, 0.9)) }
    c.addPath(path); c.setFillColor(appearance == .tinted ? rgb(0xFFFFFF) : rgb(amberLight)); c.fillPath()
    c.setShadow(offset: .zero, blur: 0, color: nil)
    let core = sparkPath(center: center, top: arm * 0.45, right: arm * 0.45, bottom: arm * 0.45, left: arm * 0.45, pinch: arm * 0.08)
    c.addPath(core); c.setFillColor(rgb(0xFFFFFF, 0.95)); c.fillPath()
    c.restoreGState()
}

// Variant A: the spark, its top arm reaching higher, as a spark rising.
func drawA(_ appearance: Appearance) {
    let c = makeContext()
    drawBackground(c, appearance: appearance)
    let path = sparkPath(center: CGPoint(x: 500, y: 492), top: 360, right: 235, bottom: 275, left: 235, pinch: 46)
    fillGlyph(c, path: path, appearance: appearance, glow: true)
    drawGlint(c, at: CGPoint(x: 756, y: 744), arm: 62, appearance: appearance)
    write(c, "A-\(appearance.rawValue)")
}

// Variant B: the wordmark's "i", a bold rounded stem with the spark as its dot.
func drawB(_ appearance: Appearance) {
    let c = makeContext()
    drawBackground(c, appearance: appearance)
    let stem = CGPath(roundedRect: CGRect(x: 512 - 92, y: 190, width: 184, height: 440), cornerWidth: 92, cornerHeight: 92, transform: nil)
    fillGlyph(c, path: stem, appearance: appearance, glow: true)
    let dot = sparkPath(center: CGPoint(x: 512, y: 760), top: 120, right: 120, bottom: 120, left: 120, pinch: 22)
    c.saveGState()
    if appearance != .tinted { c.setShadow(offset: .zero, blur: 60, color: rgb(amberLight, 0.9)) }
    c.addPath(dot); c.setFillColor(appearance == .tinted ? rgb(0xFFFFFF) : rgb(amberLight)); c.fillPath()
    c.restoreGState()
    write(c, "B-\(appearance.rawValue)")
}

// Variant C: an ember with a tail sweeping in from the lower left, a spark in flight.
func drawC(_ appearance: Appearance) {
    let c = makeContext()
    drawBackground(c, appearance: appearance)
    let p = CGMutablePath()
    let head = CGPoint(x: 600, y: 600), r: CGFloat = 170
    p.addArc(center: head, radius: r, startAngle: .pi * 0.75, endAngle: .pi * 1.75 + .pi, clockwise: false)
    // The tail: from the head's lower-left tangents to a point far down-left, bowed outward.
    let tail = CGPoint(x: 150, y: 150)
    p.move(to: CGPoint(x: head.x - r * cos(.pi * 0.25), y: head.y + r * sin(.pi * 0.25)))
    p.addQuadCurve(to: tail, control: CGPoint(x: 220, y: 470))
    p.addQuadCurve(to: CGPoint(x: head.x + r * cos(.pi * 0.25), y: head.y - r * sin(.pi * 0.25)), control: CGPoint(x: 470, y: 220))
    p.closeSubpath()
    fillGlyph(c, path: p, appearance: appearance, glow: true)
    drawGlint(c, at: CGPoint(x: 790, y: 790), arm: 58, appearance: appearance)
    write(c, "C-\(appearance.rawValue)")
}

for appearance in [Appearance.any, .dark, .tinted] {
    drawA(appearance); drawB(appearance); drawC(appearance)
}

// Layers of A for Icon Composer: the background alone, the spark alone, the glint alone (transparent).
do {
    let c = makeContext(); drawBackground(c, appearance: .any); write(c, "layer-background")
    let s = makeContext()
    fillGlyph(s, path: sparkPath(center: CGPoint(x: 500, y: 492), top: 360, right: 235, bottom: 275, left: 235, pinch: 46), appearance: .any, glow: false)
    write(s, "layer-spark")
    let g = makeContext(); drawGlint(g, at: CGPoint(x: 756, y: 744), arm: 62, appearance: .any); write(g, "layer-glint")
}

// Refinements of A: a fuller body (larger pinch) and an optional tilt, plus a strip at home-screen size to judge.
func drawARefined(_ appearance: Appearance, pinch: CGFloat, tilt: CGFloat, name: String, opaque: Bool = false) -> CGContext {
    let c = makeContext(opaque: opaque)
    drawBackground(c, appearance: appearance)
    let center = CGPoint(x: 500, y: 492)
    var transform = CGAffineTransform(translationX: center.x, y: center.y).rotated(by: tilt).translatedBy(x: -center.x, y: -center.y)
    let base = sparkPath(center: center, top: 350, right: 240, bottom: 280, left: 240, pinch: pinch)
    let path = base.copy(using: &transform)!
    fillGlyph(c, path: path, appearance: appearance, glow: true)
    drawGlint(c, at: CGPoint(x: 760, y: 740), arm: 62, appearance: appearance)
    write(c, name)
    return c
}

var strip: [CGImage] = []
for (index, variant) in [(46, 0.0), (68, 0.0), (68, -0.14), (84, -0.10)].enumerated() {
    let c = drawARefined(.any, pinch: CGFloat(variant.0), tilt: CGFloat(variant.1), name: "A\(index + 1)-any")
    strip.append(c.makeImage()!)
}
// Four icons at 180 px with iOS corner radius on a dark field, as a home screen would show them.
let preview = CGContext(data: nil, width: 4 * 260, height: 300, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
preview.setFillColor(rgb(0x1C1C1E)); preview.fill(CGRect(x: 0, y: 0, width: 4 * 260, height: 300))
for (i, image) in strip.enumerated() {
    let rect = CGRect(x: 40 + CGFloat(i) * 260, y: 60, width: 180, height: 180)
    preview.saveGState()
    preview.addPath(CGPath(roundedRect: rect, cornerWidth: 40, cornerHeight: 40, transform: nil)); preview.clip()
    preview.interpolationQuality = .high
    preview.draw(image, in: rect)
    preview.restoreGState()
}
write(preview, "preview-strip")

// The final set: the fuller upright spark in every appearance, plus its layers for Icon Composer.
for appearance in [Appearance.any, .dark, .tinted] {
    _ = drawARefined(appearance, pinch: 68, tilt: 0, name: "final-\(appearance.rawValue)", opaque: true)
}
do {
    let s = makeContext()
    fillGlyph(s, path: sparkPath(center: CGPoint(x: 500, y: 492), top: 350, right: 240, bottom: 280, left: 240, pinch: 68), appearance: .any, glow: false)
    write(s, "final-layer-spark")
    let g = makeContext(); drawGlint(g, at: CGPoint(x: 760, y: 740), arm: 62, appearance: .any); write(g, "final-layer-glint")
    let b = makeContext(); drawBackground(b, appearance: .any); write(b, "final-layer-background")
}
