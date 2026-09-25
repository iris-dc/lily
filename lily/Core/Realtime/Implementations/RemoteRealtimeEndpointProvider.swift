import Foundation

/// The realtime endpoint of a real backend: the debug `-realtime-endpoint` argument first, else what `GET /api/me`
/// answered, else the production constant (`nil` in debug builds, so a local Laurel gets catch-up only).
final class RemoteRealtimeEndpointProvider: RealtimeEndpointProvider {
    private let override: URL?
    private let me: MeStore

    init(override: URL?, me: MeStore) {
        self.override = override
        self.me = me
    }

    func endpoint() async -> URL? {
        override ?? me.realtimeEndpoint ?? AppConfig.Realtime.productionEndpoint
    }
}
