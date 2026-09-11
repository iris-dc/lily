import Foundation

/// `APIClient` over `URLSession`. Knows the base URL, the JSON conventions and the local identity header, nothing else.
final class URLSessionAPIClient: APIClient {
    private let session: URLSession
    private let baseURL: URL
    private let identity: any IdentityProvider
    private let sendsLocalUserHeader: Bool
    private let logger: any Logging
    private let decoder = APIJSONCoding.makeDecoder()
    private let encoder = APIJSONCoding.makeEncoder()

    init(session: URLSession = URLSessionAPIClient.makeSession(),
         baseURL: URL = AppConfig.API.baseURL,
         identity: any IdentityProvider,
         sendsLocalUserHeader: Bool = AppConfig.API.sendsLocalUserHeader,
         logger: any Logging) {
        self.session = session
        self.baseURL = baseURL
        self.identity = identity
        self.sendsLocalUserHeader = sendsLocalUserHeader
        self.logger = logger
    }

    /// One session for the app's lifetime with the configured timeout. No delegate, so there is nothing to invalidate.
    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = AppConfig.API.requestTimeout
        return URLSession(configuration: configuration)
    }

    func send<Response: Decodable>(_ request: APIRequest<Response>) async throws -> Response {
        let endpoint = "\(request.method.rawValue) \(request.path)"
        logger.debug(.network, "Sending \(endpoint)")
        let (data, response) = try await perform(makeURLRequest(request), endpoint: endpoint)
        guard let http = response as? HTTPURLResponse else {
            logger.error(.network, "\(endpoint) returned a non-HTTP response")
            throw APIError.notHTTPResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw failure(status: http.statusCode, data: data, endpoint: endpoint)
        }
        return try decode(Response.self, from: data, endpoint: endpoint)
    }

    private func makeURLRequest<Response>(_ request: APIRequest<Response>) throws -> URLRequest {
        var url = baseURL.appending(path: request.path)
        if !request.queryItems.isEmpty {
            url.append(queryItems: request.queryItems)
        }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.setValue(AppConfig.API.Headers.json, forHTTPHeaderField: AppConfig.API.Headers.accept)
        if let body = request.body {
            urlRequest.httpBody = try encoder.encode(body)
            urlRequest.setValue(AppConfig.API.Headers.json, forHTTPHeaderField: AppConfig.API.Headers.contentType)
        }
        if sendsLocalUserHeader, let userID = identity.currentUserID {
            urlRequest.setValue(userID, forHTTPHeaderField: AppConfig.API.Headers.localUserID)
        }
        return urlRequest
    }

    /// Transport failures are logged and rethrown as they are, so callers can still recognise a cancellation.
    private func perform(_ urlRequest: URLRequest, endpoint: String) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: urlRequest)
        } catch {
            if AppError.isCancellation(error) {
                logger.debug(.network, "\(endpoint) cancelled")
            } else {
                logger.warning(.network, "\(endpoint) failed before a response: \(error.localizedDescription)")
            }
            throw error
        }
    }

    /// Reads the backend's `{code, message}` when there is one; the log carries the code, never the body itself.
    private func failure(status: Int, data: Data, endpoint: String) -> APIError {
        let body = try? decoder.decode(APIErrorBody.self, from: data)
        let code = body.map { " (\($0.code))" } ?? ""
        logger.error(.network, "\(endpoint) failed with status \(status)\(code)")
        return .http(status: status, body: body)
    }

    private func decode<Response: Decodable>(_ type: Response.Type, from data: Data, endpoint: String) throws -> Response {
        do {
            return try decoder.decode(type, from: data)
        } catch {
            logger.error(.network, "\(endpoint) returned a body that does not decode as \(type): \(error)")
            throw APIError.decodingFailed
        }
    }
}
