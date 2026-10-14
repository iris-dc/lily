import CoreGraphics
import Foundation
import Testing
@testable import lily

struct FilmGrainTests {
    private let size = 16
    private let seed: UInt64 = 42

    @Test func producesOneByteTilePerPixel() {
        #expect(FilmGrain.pixels(size: size, seed: seed).count == size * size)
    }

    @Test func isDeterministicForASeed() {
        let first = FilmGrain.pixels(size: size, seed: seed)
        let second = FilmGrain.pixels(size: size, seed: seed)
        let other = FilmGrain.pixels(size: size, seed: seed + 1)
        #expect(first == second)
        #expect(first != other)
    }

    @Test func isNotFlat() {
        #expect(Set(FilmGrain.pixels(size: size, seed: seed)).count > 1)
    }

    @Test func frameIndexCyclesThroughEveryTileAndKeepsMovingAtWallClockMagnitudes() {
        let count = 12, rate = 24.0
        var seen = Set<Int>()
        for t in stride(from: 0.0, through: 1.0, by: 1 / rate / 2) {
            let index = FilmGrain.frameIndex(at: t, frameCount: count, frameRate: rate)
            #expect(index >= 0 && index < count)
            seen.insert(index)
        }
        #expect(seen.count == count)
        // Step by 1.5 frames: exactly one frame can land a rounding error short of the boundary and floor to the same tile.
        let now: TimeInterval = 800_000_000
        #expect(FilmGrain.frameIndex(at: now, frameCount: count, frameRate: rate)
            != FilmGrain.frameIndex(at: now + 1.5 / rate, frameCount: count, frameRate: rate))
    }

    /// The wall clock arrives as `timeIntervalSinceReferenceDate`, which is negative on a device whose clock is set
    /// before 2001.
    @Test func aNegativeTimeStaysInRange() {
        let count = 12, rate = 24.0
        #expect(FilmGrain.frameIndex(at: -0.01, frameCount: count, frameRate: rate) == 11)
        // `Int(-2.4)` truncates to -2, so clamping with `min` alone would let a negative index through.
        #expect(FilmGrain.frameIndex(at: -0.1, frameCount: count, frameRate: rate) == 9)
        #expect(FilmGrain.frameIndex(at: -0.5, frameCount: count, frameRate: rate)
            == FilmGrain.frameIndex(at: 0, frameCount: count, frameRate: rate))
        let beforeTheReferenceDate: TimeInterval = -800_000_000.3
        let index = FilmGrain.frameIndex(at: beforeTheReferenceDate, frameCount: count, frameRate: rate)
        #expect((0..<count).contains(index))
    }

    @Test func buildsAGrayscaleImage() {
        let image = FilmGrain.makeImage(size: size, seed: seed)
        #expect(image?.width == size)
        #expect(image?.height == size)
        #expect(image?.bitsPerPixel == 8)
    }
}
