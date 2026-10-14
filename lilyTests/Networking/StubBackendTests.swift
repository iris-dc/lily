import Foundation
import Testing
@testable import lily

/// A `StubBackend` lives as long as the test holds it: its host answers while it does and is unstubbed once it is gone.
struct StubBackendTests {
    @Test func aStubBackendIsReleasedWithItsTest() async throws {
        weak var released: StubBackend?
        do {
            let backend = StubBackend(status: 200, json: "{}")
            released = backend

            _ = try await backend.makeSession().data(from: backend.baseURL)

            #expect(backend.requests.count == 1)
        }
        #expect(released == nil)
    }

    @Test func aReleasedBackendsHostIsNoLongerStubbed() async throws {
        let host: String
        do {
            let backend = StubBackend(status: 200, json: "{}")
            host = backend.host
            _ = try await backend.makeSession().data(from: backend.baseURL)
        }

        let error = await #expect(throws: URLError.self) {
            _ = try await StubURLProtocol.makeSession().data(from: URL(string: "http://\(host)/")!)
        }

        #expect(error?.code == .unsupportedURL)
    }

    @Test func aLiveBackendKeepsAnsweringItsHost() async throws {
        let backend = StubBackend(status: 200, json: "{}")
        let session = backend.makeSession()

        let (_, first) = try await session.data(from: backend.baseURL)
        let (_, second) = try await session.data(from: backend.baseURL.appending(path: "again"))

        #expect((first as? HTTPURLResponse)?.statusCode == 200)
        #expect((second as? HTTPURLResponse)?.statusCode == 200)
        #expect(backend.requests.count == 2)
        #expect(backend.requests.last?.url?.lastPathComponent == "again")
    }
}
