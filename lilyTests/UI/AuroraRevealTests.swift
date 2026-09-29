import Foundation
import Testing
@testable import lily

struct AuroraRevealTests {
    private let start = Date(timeIntervalSinceReferenceDate: 800_000_000)
    private let duration: TimeInterval = 3.5

    @Test func isDarkAtTheStart() {
        #expect(AuroraReveal.opacity(at: start, start: start, duration: duration) == 0)
    }

    @Test func isHalfwayAtTheMidpoint() {
        #expect(AuroraReveal.opacity(at: start + duration / 2, start: start, duration: duration) == 0.5)
    }

    @Test func isFullyShownFromTheEndOn() {
        #expect(AuroraReveal.opacity(at: start + duration, start: start, duration: duration) == 1)
        #expect(AuroraReveal.opacity(at: start + duration * 100, start: start, duration: duration) == 1)
    }

    @Test func staysDarkBeforeTheStart() {
        #expect(AuroraReveal.opacity(at: start - 1, start: start, duration: duration) == 0)
    }

    @Test func neverRunsBackwards() {
        var previous = 0.0
        for step in stride(from: 0.0, through: duration, by: 0.05) {
            let opacity = AuroraReveal.opacity(at: start + step, start: start, duration: duration)
            #expect(opacity >= previous)
            previous = opacity
        }
    }

    @Test func showsAtOnceWithoutADuration() {
        #expect(AuroraReveal.opacity(at: start, start: start, duration: 0) == 1)
    }

    @Test func defaultsToTheDesignTokenDuration() {
        let end = start + DesignTokens.Aurora.revealDuration
        #expect(AuroraReveal.opacity(at: end - 0.1, start: start) < 1)
        #expect(AuroraReveal.opacity(at: end, start: start) == 1)
    }
}
