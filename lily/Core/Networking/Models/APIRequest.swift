import Foundation

nonisolated enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}

/// One call to the backend: where, how, with what, and what comes back.
nonisolated struct APIRequest<Response: Decodable>: Sendable {
    let method: HTTPMethod
    /// Absolute path under `AppConfig.API.baseURL`, such as `/api/events`.
    let path: String
    var queryItems: [URLQueryItem] = []
    /// Encoded as the JSON body when present.
    var body: (any Encodable & Sendable)?

    static func get(_ path: String, query: [URLQueryItem] = []) -> APIRequest {
        APIRequest(method: .get, path: path, queryItems: query)
    }

    static func post(_ path: String, body: (any Encodable & Sendable)? = nil) -> APIRequest {
        APIRequest(method: .post, path: path, body: body)
    }

    static func put(_ path: String, body: any Encodable & Sendable) -> APIRequest {
        APIRequest(method: .put, path: path, body: body)
    }

    static func delete(_ path: String) -> APIRequest {
        APIRequest(method: .delete, path: path)
    }
}
