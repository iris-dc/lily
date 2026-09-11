import Foundation

/// Transport boundary to the backend. Implementations build the URL, attach identity, and encode and decode JSON.
protocol APIClient {
    /// Throws `APIError` for HTTP and decoding failures and lets transport failures (`URLError`) through unchanged,
    /// so callers can still tell a cancelled request from a failed one.
    func send<Response: Decodable>(_ request: APIRequest<Response>) async throws -> Response
}
