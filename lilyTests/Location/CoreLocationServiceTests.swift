import Foundation
import Testing
@testable import lily

@MainActor
struct CoreLocationServiceTests {
    private let logger = SpyLogger()
    private let berlin = AppConfig.Location.mockCenter

    private func makeService(_ source: FakeLocationUpdateSource, timeout: Duration = .seconds(5)) -> CoreLocationService {
        CoreLocationService(logger: logger, timeout: timeout, source: source)
    }

    private func locationLog(containing fragment: String) -> Bool {
        logger.messages(in: .location).contains { $0.contains(fragment) }
    }

    @Test func firstCoordinateIsReturnedAndStreamClosed() async {
        let source = FakeLocationUpdateSource(fixes: [LocationFix(coordinate: berlin, isDenied: false)])

        #expect(await makeService(source).currentLocation() == berlin)

        #expect(locationLog(containing: "acquired"))
        #expect(source.wasTerminated)
    }

    @Test func statusOnlyUpdatesAreSkippedUntilACoordinateArrives() async {
        let fixes = [LocationFix(coordinate: nil, isDenied: false), LocationFix(coordinate: berlin, isDenied: false)]
        #expect(await makeService(FakeLocationUpdateSource(fixes: fixes)).currentLocation() == berlin)
    }

    @Test func deniedPermissionYieldsNilWithoutClaimingAFix() async {
        let source = FakeLocationUpdateSource(fixes: [LocationFix(coordinate: nil, isDenied: true)])

        #expect(await makeService(source).currentLocation() == nil)

        #expect(locationLog(containing: "denied"))
        #expect(!locationLog(containing: "acquired"))
    }

    @Test func timeoutYieldsNilAndClosesTheStream() async {
        let source = FakeLocationUpdateSource()

        #expect(await makeService(source, timeout: .milliseconds(50)).currentLocation() == nil)

        #expect(locationLog(containing: "No location fix"))
        #expect(!locationLog(containing: "acquired"))
        #expect(source.wasTerminated)
    }

    @Test func sourceFailureYieldsNilAndWarns() async {
        let source = FakeLocationUpdateSource(error: AppError.network)

        #expect(await makeService(source).currentLocation() == nil)

        #expect(locationLog(containing: "unavailable"))
        #expect(!locationLog(containing: "acquired"))
    }

    /// Switching tabs cancels the view's task; the stream must close with it instead of running to the timeout.
    @Test func cancellingTheCallerClosesTheStream() async {
        let source = FakeLocationUpdateSource()
        let service = makeService(source, timeout: .seconds(30))
        let request = Task { await service.currentLocation() }

        request.cancel()

        #expect(await request.value == nil)
        #expect(source.wasTerminated)
        #expect(!locationLog(containing: "acquired"))
    }
}
