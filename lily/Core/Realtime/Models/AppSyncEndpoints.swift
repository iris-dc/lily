import Foundation

/// The two addresses of one AppSync Events API, derived from whichever form arrives (`GET /api/me` answers the HTTP
/// endpoint; the debug `-realtime-endpoint` argument may name either): on the AWS domain the socket host swaps
/// `appsync-api` for `appsync-realtime-api`; a custom domain serves both paths itself. The socket connects to
/// `wss://<socket host>/event/realtime`, and every authorization names the HTTP host.
nonisolated struct AppSyncEndpoints: Hashable, Sendable {
    let socketURL: URL
    /// The HTTP endpoint's host, named in the handshake's and every subscribe's authorization.
    let httpHost: String

    init?(endpoint: URL) {
        guard var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false),
              let host = components.host, !host.isEmpty else { return nil }
        let names = AppConfig.Realtime.self
        if host.hasSuffix(names.awsDomainSuffix) {
            httpHost = host.replacingOccurrences(of: names.socketHostFragment, with: names.httpHostFragment)
            components.host = httpHost.replacingOccurrences(of: names.httpHostFragment,
                                                            with: names.socketHostFragment)
        } else {
            httpHost = host
        }
        components.scheme = names.socketScheme
        components.path = names.socketPath
        components.query = nil
        guard let socketURL = components.url else { return nil }
        self.socketURL = socketURL
    }
}
