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

    /// `+`, `&` and `=` are percent-encoded along with everything `urlQueryAllowed` refuses: `URL.append(queryItems:)`
    /// leaves `+` bare, which the backend's servlet layer reads as a space, so a `+` typed into a search would never
    /// reach Laurel.
    private static let queryAllowed = CharacterSet.urlQueryAllowed.subtracting(CharacterSet(charactersIn: "+&="))

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

    /// Log lines name the endpoint by `logPath` when the request has one, so a path carrying a value the log must not
    /// hold (the device token) is logged redacted.
    func send<Response: Decodable>(_ request: APIRequest<Response>) async throws -> Response {
        let endpoint = "\(request.method.rawValue) \(request.logPath ?? request.path)"
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
        var urlRequest = URLRequest(url: Self.url(baseURL, path: request.path, query: request.queryItems))
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

    private static func url(_ base: URL, path: String, query: [URLQueryItem]) -> URL {
        let url = base.appending(path: path)
        guard !query.isEmpty, var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url }
        components.percentEncodedQuery = query.map { item in
            let name = item.name.addingPercentEncoding(withAllowedCharacters: queryAllowed) ?? item.name
            guard let value = item.value else { return name }
            return "\(name)=\(value.addingPercentEncoding(withAllowedCharacters: queryAllowed) ?? value)"
        }.joined(separator: "&")
        return components.url ?? url
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
    /// backend sends; a date is ignored); the log carries the code, never the body. A refusal the product expects (a
    /// known code on a 4xx, a rejected token, a throttle) is a warning, since the view model logs its own line; a fault
    /// (a 5xx, an unreadable body, an unknown code such as `VALIDATION_FAILED`, which means client validation drifted)
    /// is an error.
    private func failure(_ response: HTTPURLResponse, data: Data, endpoint: String) -> APIError {
        let status = response.statusCode
        let body = try? decoder.decode(APIErrorBody.self, from: data)
        let code = body.map { " (\($0.code))" } ?? ""
        let level: LogLevel = Self.isRefusal(status: status, body: body) ? .warning : .error
        logger.log(level, .network, "\(endpoint) failed with status \(status)\(code)")
        let retryAfter = response.value(forHTTPHeaderField: AppConfig.API.Headers.retryAfter).flatMap(TimeInterval.init)
        return .http(status: status, body: body, retryAfter: retryAfter)
    }

    private static func isRefusal(status: Int, body: APIErrorBody?) -> Bool {
        guard AppConfig.API.clientErrorStatuses.contains(status) else { return false }
        let isKnownCode = body.map { BackendErrorCode(rawValue: $0.code) != nil } ?? false
        return isKnownCode || status == AppConfig.API.unauthorizedStatus || status == AppConfig.API.rateLimitedStatus
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
