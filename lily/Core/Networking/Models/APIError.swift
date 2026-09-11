import Foundation

/// Body the backend sends with every non-2xx response it produces itself (a 401 from the framework has none).
nonisolated struct APIErrorBody: Decodable, Equatable, Sendable {
    let code: String
    let message: String
}

/// Failures of a backend call other than transport ones, which stay `URLError`.
nonisolated enum APIError: Error, Equatable, Sendable {
    case http(status: Int, body: APIErrorBody?)
    case notHTTPResponse
    case decodingFailed
}
