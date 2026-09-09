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

    @Test func buildsAGrayscaleImage() {
        let image = FilmGrain.makeImage(size: size, seed: seed)
        #expect(image?.width == size)
        #expect(image?.height == size)
        #expect(image?.bitsPerPixel == 8)
    }
}
