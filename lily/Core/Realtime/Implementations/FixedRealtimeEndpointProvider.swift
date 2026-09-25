import Foundation

/// A known endpoint, for the mock run (the in-memory transport ignores it) and for tests.
final class FixedRealtimeEndpointProvider: RealtimeEndpointProvider {
    private let url: URL?

    init(url: URL?) {
        self.url = url
    }

    func endpoint() async -> URL? {
        url
    }
}
