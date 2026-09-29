import Foundation
import Testing
@testable import lily

@MainActor
struct RemoteInboxRepositoryTests {
    /// `nonisolated`: `@Test(arguments:)` reads it off the main actor.
    nonisolated private static let codeCases: [(code: String, expected: AppError)] = [
        ("INVITE_NOT_PENDING", .inviteNotPending), ("INBOX_ITEM_NOT_FOUND", .inviteNotPending),
        ("INVITE_EXPIRED", .inviteExpired), ("BANNED", .bannedFromGroup), ("GROUP_FULL", .groupFull),
        ("GROUP_NOT_FOUND", .groupNotFound), ("MEMBERSHIP_LIMIT", .membershipLimitReached),
        ("TERMS_REQUIRED", .termsRequired), ("ACCOUNT_SUSPENDED", .accountSuspended), ("TRY_AGAIN", .tryAgain),
        ("VALIDATION_FAILED", .inviteActionFailed),
    ]
    private static let otherFailures: [APIError] = [
        .http(status: 500, body: nil), .http(status: 403, body: nil), .decodingFailed, .notHTTPResponse,
    ]

    private let client = FakeAPIClient()
    private let page = InboxPage.fixture([.invite()], hasMore: true, nextBefore: "01J9A", lastReadId: "01J9A")

    private var repository: RemoteInboxRepository { RemoteInboxRepository(client: client) }

    @Test func theNewestPageAsksForTheLimitAlone() async throws {
        client.responses = [page]

        #expect(try await repository.page(before: nil, limit: 50) == page)
        let request = try #require(client.requests.first)
        #expect(request.method == .get && request.path == "/api/me/inbox" && request.body == nil)
        #expect(request.queryItems == [URLQueryItem(name: "limit", value: "50")])
    }

    @Test func anEarlierPageNamesTheCursorBeforeTheLimit() async throws {
        client.responses = [page]

        _ = try await repository.page(before: "01J9A", limit: 20)

        #expect(client.requests.first?.queryItems == [URLQueryItem(name: "before", value: "01J9A"),
                                                      URLQueryItem(name: "limit", value: "20")])
    }

    @Test func markReadPutsTheItemIdAndAnswersTheMarker() async throws {
        client.responses = [InboxReadMarker(lastReadId: "01J9B")]

        #expect(try await repository.markRead(itemID: "01J9A") == "01J9B")
        let request = try #require(client.requests.first)
        #expect(request.method == .put && request.path == "/api/me/inbox/read")
        #expect(request.body as? InboxReadPayload == InboxReadPayload(itemId: "01J9A"))
    }

    @Test func acceptAndDeclinePostToTheItemWithoutABody() async throws {
        let accepted = InboxItem.invite(id: "i1", status: .accepted)
        let declined = InboxItem.invite(id: "i1", status: .declined)
        client.responses = [InviteAcceptance(item: accepted, group: .fixture(id: "g3", role: .member)),
                            InviteDeclination(item: declined)]

        let acceptance = try await repository.accept(itemID: "i1")
        #expect(acceptance.item == accepted && acceptance.group.isMember)
        #expect(try await repository.decline(itemID: "i1") == declined)

        #expect(client.requests.map(\.method) == [.post, .post])
        #expect(client.requests.map(\.path) == ["/api/me/inbox/i1/accept", "/api/me/inbox/i1/decline"])
        #expect(client.requests.allSatisfy { $0.body == nil && $0.queryItems.isEmpty })
    }

    @Test(arguments: codeCases)
    func backendCodesMapToAppErrors(code: String, expected: AppError) async {
        client.error = APIError.http(status: 409, body: APIErrorBody(code: code, message: "m"))

        await #expect(throws: expected) { try await repository.accept(itemID: "i1") }
        await #expect(throws: expected) { try await repository.decline(itemID: "i1") }
    }

    @Test func otherFailuresOnReadsBecomeInboxUnavailableAndOnAnswersInviteActionFailed() async {
        for error in Self.otherFailures {
            client.error = error
            await #expect(throws: AppError.inboxUnavailable) { try await repository.page(before: nil, limit: 50) }
            await #expect(throws: AppError.inboxUnavailable) { try await repository.markRead(itemID: "i1") }
            await #expect(throws: AppError.inviteActionFailed) { try await repository.accept(itemID: "i1") }
            await #expect(throws: AppError.inviteActionFailed) { try await repository.decline(itemID: "i1") }
        }
    }

    @Test func statusOnlyFailuresAndTransportKeepTheSharedMapping() async {
        client.error = APIError.http(status: 401, body: nil)
        await #expect(throws: AppError.sessionExpired) { try await repository.page(before: nil, limit: 50) }

        client.error = APIError.http(status: 429, body: nil)
        await #expect(throws: AppError.rateLimited(retryAfter: nil)) { try await repository.accept(itemID: "i1") }

        client.error = URLError(.notConnectedToInternet)
        await #expect(throws: AppError.network) { try await repository.decline(itemID: "i1") }

        client.error = URLError(.cancelled)
        await #expect(throws: URLError(.cancelled)) { try await repository.page(before: nil, limit: 50) }
    }
}
