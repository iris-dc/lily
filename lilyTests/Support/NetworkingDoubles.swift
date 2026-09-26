import Foundation
import Synchronization
import Testing
@testable import lily

/// One request as a repository handed it to the client, without the generic response type.
struct RecordedRequest {
    let method: HTTPMethod
    let path: String
    let queryItems: [URLQueryItem]
    let body: (any Encodable & Sendable)?
}

/// Scripted `APIClient`: records every request and answers from a queue of responses, or throws `error`.
/// A cancelled task gets `CancellationError` before anything is recorded, as it would from `URLSession`.
@MainActor
final class FakeAPIClient: APIClient {
    /// Dequeued one per `send`; each must have the request's `Response` type.
    var responses: [Any] = []
    var error: (any Error)?
    private(set) var requests: [RecordedRequest] = []

    func send<Response: Decodable>(_ request: APIRequest<Response>) async throws -> Response {
        try Task.checkCancellation()
        requests.append(RecordedRequest(method: request.method,
                                        path: request.path,
                                        queryItems: request.queryItems,
                                        body: request.body))
        if let error { throw error }
        guard !responses.isEmpty, let response = responses.removeFirst() as? Response else {
            Issue.record("No \(Response.self) queued for \(request.method.rawValue) \(request.path)")
            throw APIError.decodingFailed
        }
        return response
    }
}

/// `URLProtocol` answering from per-host handlers, so tests running in parallel each stub their own backend.
final class StubURLProtocol: URLProtocol {
    struct Response: Sendable {
        let status: Int
        let body: Data
        let headers: [String: String]

        init(status: Int, json: String = "", headers: [String: String] = [:]) {
            self.status = status
            self.body = Data(json.utf8)
            self.headers = headers
        }
    }

    typealias Handler = @Sendable (URLRequest) -> Result<Response, URLError>
    private static let handlers = Mutex<[String: Handler]>([:])

    static func register(host: String, handler: @escaping Handler) {
        handlers.withLock { $0[host] = handler }
    }

    override static func canInit(with request: URLRequest) -> Bool { true }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url, let host = url.host(), let handler = Self.handlers.withLock({ $0[host] }) else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }
        switch handler(request) {
        case .success(let response):
            let http = HTTPURLResponse(url: url, statusCode: response.status, httpVersion: nil, headerFields: response.headers)!
            client?.urlProtocol(self, didReceive: http, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: response.body)
            client?.urlProtocolDidFinishLoading(self)
        case .failure(let error):
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

/// A stubbed backend on a host of its own. Records what it received, with the body materialised into `httpBody`.
final class StubBackend: Sendable {
    let baseURL: URL
    private let recorded = Mutex<[URLRequest]>([])

    var requests: [URLRequest] { recorded.withLock { $0 } }

    init(respond: @escaping @Sendable (URLRequest) -> Result<StubURLProtocol.Response, URLError>) {
        let host = "laurel-\(UUID().uuidString.lowercased()).test"
        baseURL = URL(string: "http://\(host)")!
        StubURLProtocol.register(host: host) { request in
            var received = request
            received.httpBody = request.bodyData
            self.recorded.withLock { $0.append(received) }
            return respond(request)
        }
    }

    /// Answers every request with the same status, body and headers.
    convenience init(status: Int = 200, json: String = "", headers: [String: String] = [:]) {
        self.init { _ in .success(StubURLProtocol.Response(status: status, json: json, headers: headers)) }
    }

    func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}

private extension URLRequest {
    /// `URLSession` hands protocols the body as a stream, never as `httpBody`.
    var bodyData: Data? {
        if let httpBody { return httpBody }
        guard let stream = httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        let capacity = 4096
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: capacity)
        defer { buffer.deallocate() }
        while stream.hasBytesAvailable {
            let count = stream.read(buffer, maxLength: capacity)
            guard count > 0 else { break }
            data.append(buffer, count: count)
        }
        return data
    }
}

/// JSON exactly as the contract shows it, with fields the app does not read yet left in on purpose.
enum ContractSamples {
    static let event = """
    {"id":"evt_01J","title":"Sunset 5-a-side","type":"football","startsAt":"2026-09-13T17:00:00Z",\
    "location":{"name":"Riverside Pitch 2","coordinate":{"latitude":52.529,"longitude":13.387}},\
    "capacity":10,"participantCount":6,"hostUserId":"seed-marta","hostName":"Marta","isJoined":false,\
    "description":"Bring both colours","skillLevel":"intermediate","price":{"amount":7.5,"currencyCode":"EUR"}}
    """
    static let eventList = "[\(event)]"
    static let minimalEvent = """
    {"id":"evt_02","title":"Anything goes","type":"other","startsAt":"2026-09-13T17:00:00Z",\
    "location":{"name":"Park","coordinate":{"latitude":52.5,"longitude":13.4}},"capacity":2,"participantCount":1,"hostName":"Dev"}
    """

    static func profile(createdAt: String = "2026-09-11T10:00:00Z") -> String {
        #"{"userId":"u-1","displayName":"Apple Tester","createdAt":"\#(createdAt)"}"#
    }
}
