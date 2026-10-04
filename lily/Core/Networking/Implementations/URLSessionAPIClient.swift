import Foundation

/// `APIClient` over `URLSession`. Knows the base URL, the JSON conventions, the two identity headers and the app
/// version header, nothing else.
final class URLSessionAPIClient: APIClient {
    private let session: URLSession
    private let baseURL: URL
    private let identity: any IdentityProvider
    private let tokenProvider: (any AuthTokenProvider)?
    private let sendsLocalUserHeader: Bool
    private let appVersion: String
    private let logger: any Logging
    private let decoder = APIJSONCoding.makeDecoder()
    private let encoder = APIJSONCoding.makeEncoder()

    /// `tokenProvider` is `nil` when auth is mocked: no token exists, and none is sent.
    init(session: URLSession = URLSessionAPIClient.makeSession(),
         baseURL: URL = AppConfig.API.baseURL,
         identity: any IdentityProvider,
         tokenProvider: (any AuthTokenProvider)? = nil,
         sendsLocalUserHeader: Bool = AppConfig.API.sendsLocalUserHeader,
         appVersion: AppVersion = .current(),
         logger: any Logging) {
        self.session = session
        self.baseURL = baseURL
        self.identity = identity
        self.tokenProvider = tokenProvider
        self.sendsLocalUserHeader = sendsLocalUserHeader
        self.appVersion = appVersion.headerValue
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
        let (data, response) = try await perform(try await makeURLRequest(request), endpoint: endpoint)
        guard let http = response as? HTTPURLResponse else {
            logger.error(.network, "\(endpoint) returned a non-HTTP response")
            throw APIError.notHTTPResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw failure(http, data: data, endpoint: endpoint)
        }
        return try decode(Response.self, from: data, endpoint: endpoint)
    }

    /// The token is read per request, only while the app's session has a user, and never logged.
    private func makeURLRequest<Response>(_ request: APIRequest<Response>) async throws -> URLRequest {
        var url = baseURL.appending(path: request.path)
        if !request.queryItems.isEmpty {
            url.append(queryItems: request.queryItems)
        }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.setValue(AppConfig.API.Headers.json, forHTTPHeaderField: AppConfig.API.Headers.accept)
        urlRequest.setValue(appVersion, forHTTPHeaderField: AppConfig.API.Headers.appVersion)
        if let body = request.body {
            urlRequest.httpBody = try encoder.encode(body)
            urlRequest.setValue(AppConfig.API.Headers.json, forHTTPHeaderField: AppConfig.API.Headers.contentType)
        }
        if sendsLocalUserHeader, let userID = identity.currentUserID {
            urlRequest.setValue(userID, forHTTPHeaderField: AppConfig.API.Headers.localUserID)
        }
        // Gated on the app's session, not on Amplify's keychain: a token left behind by a rolled-back sign-in must not
        // personalise what the app shows as a guest.
        if identity.currentUserID != nil, let token = await tokenProvider?.accessToken() {
            let headers = AppConfig.API.Headers.self
            urlRequest.setValue(headers.bearerPrefix + token, forHTTPHeaderField: headers.authorization)
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

    /// Reads the backend's `{code, message}` when there is one, and `Retry-After` in seconds (the only form the
    /// backend sends; a date is ignored); the log carries the code, never the body itself.
    private func failure(_ response: HTTPURLResponse, data: Data, endpoint: String) -> APIError {
        let body = try? decoder.decode(APIErrorBody.self, from: data)
        let code = body.map { " (\($0.code))" } ?? ""
        logger.error(.network, "\(endpoint) failed with status \(response.statusCode)\(code)")
        let retryAfter = response.value(forHTTPHeaderField: AppConfig.API.Headers.retryAfter).flatMap(TimeInterval.init)
        return .http(status: response.statusCode, body: body, retryAfter: retryAfter)
    }

    /// An empty body (`204`) is an answer for the types that allow one (`EmptyDecodable`); every other type needs JSON.
    private func decode<Response: Decodable>(_ type: Response.Type, from data: Data, endpoint: String) throws -> Response {
        if data.isEmpty, let empty = (type as? any EmptyDecodable.Type)?.empty as? Response {
            return empty
        }
        do {
            return try decoder.decode(type, from: data)
        } catch {
            logger.error(.network, "\(endpoint) returned a body that does not decode as \(type): \(error)")
            throw APIError.decodingFailed
        }
    }
}
