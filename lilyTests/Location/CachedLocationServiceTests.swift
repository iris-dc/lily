import Foundation
import Testing
@testable import lily

@MainActor
struct CachedLocationServiceTests {
    private let upstream = FakeLocationService()
    private let clock = ManualClock()
    private let logger = SpyLogger()
    private let berlin = AppConfig.Location.mockCenter

    private func makeService() -> CachedLocationService {
        CachedLocationService(upstream: upstream, logger: logger) { [clock] in clock.now }
    }

    @Test func fixIsReusedWithinTTL() async {
        upstream.result = berlin
        let service = makeService()

        _ = await service.currentLocation()
        clock.advance(by: AppConfig.Location.fixTTL - .seconds(1))

        #expect(await service.currentLocation() == berlin)
        #expect(upstream.callCount == 1)
        #expect(logger.messages(in: .cache).contains { $0.contains("hit") })
    }

    @Test func fixIsRequestedAgainOnceTTLExpires() async {
        upstream.result = berlin
        let service = makeService()

        _ = await service.currentLocation()
        clock.advance(by: AppConfig.Location.fixTTL + .seconds(1))
        _ = await service.currentLocation()

        #expect(upstream.callCount == 2)
    }

    @Test func missingFixIsRememberedOnlyBriefly() async {
        upstream.result = nil
        let service = makeService()

        _ = await service.currentLocation()
        clock.advance(by: AppConfig.Location.failedFixTTL - .seconds(1))
        #expect(await service.currentLocation() == nil)
        #expect(upstream.callCount == 1)

        clock.advance(by: .seconds(2))
        upstream.result = berlin
        #expect(await service.currentLocation() == berlin)
        #expect(upstream.callCount == 2)
    }

    @Test func concurrentCallersShareOneUpstreamRequest() async {
        upstream.result = berlin
        upstream.holdsRequests = true
        let service = makeService()

        let first = Task { await service.currentLocation() }
        await settle(until: { upstream.callCount == 1 })
        let second = Task { await service.currentLocation() }
        await settle(until: { logger.messages(in: .cache).contains { $0.contains("joined") } })
        upstream.release()

        #expect(await first.value == berlin)
        #expect(await second.value == berlin)
        #expect(upstream.callCount == 1)
    }

    /// Yields to the main actor until `condition` holds, bounded so a regression fails instead of hanging.
    private func settle(until condition: () -> Bool) async {
        for _ in 0..<1_000 where !condition() {
            await Task.yield()
        }
        #expect(condition())
    }
}
