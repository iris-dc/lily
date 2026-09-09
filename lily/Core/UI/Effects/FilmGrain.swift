import CoreGraphics
import Foundation

/// Deterministic gray noise for the film-grain overlay. Generated once, tiled by the view.
nonisolated enum FilmGrain {
    /// `size * size` grayscale bytes, row-major, from a seeded xorshift so tests and launches agree.
    /// Values are squared so most pixels stay dark and only a few speckle bright: additive grain then
    /// reads as sparse film grain instead of lifting the whole surface to grey.
    static func pixels(size: Int, seed: UInt64) -> [UInt8] {
        var state = seed == 0 ? 1 : seed
        return (0..<(size * size)).map { _ in
            state = nextState(state)
            let uniform = Int(UInt8(truncatingIfNeeded: state >> 24))
            return UInt8(uniform * uniform / Int(UInt8.max))
        }
    }

    /// One `size`-by-`size` 8-bit grayscale image; `nil` only if Core Graphics refuses the buffer.
    static func makeImage(size: Int, seed: UInt64) -> CGImage? {
        let data = Data(pixels(size: size, seed: seed))
        guard let provider = CGDataProvider(data: data as CFData) else { return nil }
        return CGImage(width: size,
                       height: size,
                       bitsPerComponent: 8,
                       bitsPerPixel: 8,
                       bytesPerRow: size,
                       space: CGColorSpaceCreateDeviceGray(),
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                       provider: provider,
                       decode: nil,
                       shouldInterpolate: false,
                       intent: .defaultIntent)
    }

    /// Which of `frameCount` grain tiles is on screen at `time`, switching `frameRate` times a second.
    /// Reduced with `truncatingRemainder` first so wall-clock times keep sub-frame precision.
    static func frameIndex(at time: TimeInterval, frameCount: Int, frameRate: Double) -> Int {
        let loop = Double(frameCount) / frameRate
        let position = time.truncatingRemainder(dividingBy: loop)
        let index = Int((position < 0 ? position + loop : position) * frameRate)
        return min(index, frameCount - 1)
    }

    /// xorshift64: tiny, allocation-free and plenty random for noise nobody inspects.
    private static func nextState(_ state: UInt64) -> UInt64 {
        var x = state
        x ^= x << 13
        x ^= x >> 7
        x ^= x << 17
        return x
    }
}
