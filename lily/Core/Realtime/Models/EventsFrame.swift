import Foundation

/// One frame off the AppSync Events WebSocket, decoded leniently: only `type` is required, and a type this build does
/// not know is dropped by name, never a decode error. The keys are the service's.
nonisolated struct EventsIncomingFrame: Decodable {
    nonisolated struct FrameError: Decodable {
        let errorType: String?
        let message: String?
    }

    /// Where `connection_ack` carries the keep-alive window.
    nonisolated struct Payload: Decodable {
        let connectionTimeoutMs: Int?
    }

    enum Kind: String {
        case connectionAck = "connection_ack"
        case keepAlive = "ka"
        case subscribeSuccess = "subscribe_success"
        case subscribeError = "subscribe_error"
        case data
        case broadcastError = "broadcast_error"
        case unsubscribeSuccess = "unsubscribe_success"
        case unsubscribeError = "unsubscribe_error"
        case error
    }

    let type: String
    let id: String?
    /// A delivery's event: a stringified JSON the envelope decodes from.
    let event: String?
    let errors: [FrameError]?
    let payload: Payload?
    let connectionTimeoutMs: Int?

    var kind: Kind? { Kind(rawValue: type) }

    /// The keep-alive window the ack names, wherever the service put it, in seconds.
    var keepAliveTimeout: TimeInterval? {
        (payload?.connectionTimeoutMs ?? connectionTimeoutMs).map { TimeInterval($0) / 1_000 }
    }
}

/// The frames the client sends, and the handshake's subprotocol list. The Cognito authorization is the documented
/// object: the HTTP endpoint's host plus the JWT under `Authorization`.
nonisolated enum EventsOutgoingFrame {
    nonisolated private struct Simple: Encodable {
        let type: String
        var id: String?
    }

    nonisolated private struct Subscribe: Encodable {
        let type = "subscribe"
        let id: String
        let channel: String
        let authorization: [String: String]
    }

    private static let hostKey = "host"
    private static let authorizationKey = "Authorization"

    static func connectionInit() -> String {
        encode(Simple(type: "connection_init"))
    }

    static func subscribe(id: String, channel: String, httpHost: String, token: String) -> String {
        encode(Subscribe(id: id, channel: channel, authorization: authorization(httpHost: httpHost, token: token)))
    }

    static func unsubscribe(id: String) -> String {
        encode(Simple(type: "unsubscribe", id: id))
    }

    /// `aws-appsync-event-ws` plus the authorization as base64url JSON, the one way a WebSocket upgrade carries it.
    static func handshakeProtocols(httpHost: String, token: String) -> String {
        let header = base64url(encode(authorization(httpHost: httpHost, token: token)))
        return "\(AppConfig.Realtime.subprotocolName), \(AppConfig.Realtime.subprotocolHeaderPrefix)\(header)"
    }

    private static func authorization(httpHost: String, token: String) -> [String: String] {
        [hostKey: httpHost, authorizationKey: token]
    }

    private static func encode(_ value: some Encodable) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes, .sortedKeys]
        // Encoding strings and dictionaries of strings cannot fail; the empty frame would be refused and logged.
        guard let data = try? encoder.encode(value),
              let text = String(bytes: data, encoding: .utf8) else { return "{}" }
        return text
    }

    private static func base64url(_ text: String) -> String {
        Data(text.utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
