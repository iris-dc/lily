import Foundation
import Testing
@testable import lily

@MainActor
struct RemoteGroupRepositoryTests {
    /// `nonisolated`: `@Test(arguments:)` reads it off the main actor.
    nonisolated private static let codeCases: [(code: String, expected: AppError)] = [
        ("GROUP_NOT_FOUND", .groupNotFound), ("GROUP_FULL", .groupFull), ("NOT_A_MEMBER", .notAMember),
        ("BANNED", .bannedFromGroup), ("MEMBER_BANNED", .memberBanned), ("OWNER_CANNOT_LEAVE", .ownerCannotLeave),
        ("FORBIDDEN", .insufficientRole), ("MEMBERSHIP_LIMIT", .membershipLimitReached), ("TERMS_REQUIRED", .termsRequired),
        ("ACCOUNT_SUSPENDED", .accountSuspended), ("CONTENT_REJECTED", .contentRejected), ("TRY_AGAIN", .tryAgain),
        ("VALIDATION_FAILED", .groupActionFailed),
    ]
    private static let otherFailures: [APIError] = [
        .http(status: 500, body: nil), .http(status: 403, body: nil), .decodingFailed, .notHTTPResponse,
    ]

    private let client = FakeAPIClient()
    private let identity = FakeIdentityProvider(currentUserID: "u-1")
    private let group = SportGroup.fixture(id: "g1")

    private var repository: RemoteGroupRepository { RemoteGroupRepository(client: client, identity: identity) }

    @Test func mineAsksForTheScopeOnly() async throws {
        client.responses = [Page<SportGroup>(items: [group])]

        let page = try await repository.groups(in: .mine, cursor: nil, near: nil)

        #expect(page.items == [group])
        let request = try #require(client.requests.first)
        #expect(request.method == .get && request.path == "/api/groups" && request.body == nil)
        #expect(request.queryItems == [URLQueryItem(name: "scope", value: "mine")])
    }

    /// Discover always names the page size; the query and the type only when set; the cursor comes last.
    @Test func discoverSendsItsCriteriaAndThePageSize() async throws {
        client.responses = [Page<SportGroup>(items: []), Page<SportGroup>(items: [])]

        _ = try await repository.groups(in: .discover(query: nil, type: nil), cursor: nil, near: nil)
        _ = try await repository.groups(in: .discover(query: "kre", type: .football), cursor: "abc", near: nil)

        let limit = URLQueryItem(name: "limit", value: "\(AppConfig.Groups.discoverPageSize)")
        #expect(client.requests[0].queryItems == [URLQueryItem(name: "scope", value: "public"), limit])
        #expect(client.requests[1].queryItems == [URLQueryItem(name: "scope", value: "public"),
                                                  URLQueryItem(name: "q", value: "kre"),
                                                  URLQueryItem(name: "type", value: "football"),
                                                  limit,
                                                  URLQueryItem(name: "cursor", value: "abc")])
    }

    /// A browse around the user sends `lat`/`lon` as Explore does (two decimals, a `.`), after the page size; a name
    /// search and Mine send none, since the backend orders neither by place.
    @Test func aBrowseSendsTheCoarsePositionASearchAndMineDoNot() async throws {
        client.responses = [Page<SportGroup>(items: []), Page<SportGroup>(items: []), Page<SportGroup>(items: [])]
        let position = Coordinate(latitude: 52.5231, longitude: 13.4049)

        _ = try await repository.groups(in: .discover(query: nil, type: .padel), cursor: nil, near: position)
        _ = try await repository.groups(in: .discover(query: "kre", type: nil), cursor: nil, near: position)
        _ = try await repository.groups(in: .mine, cursor: nil, near: position)

        #expect(client.requests[0].queryItems == [URLQueryItem(name: "scope", value: "public"),
                                                  URLQueryItem(name: "type", value: "padel"),
                                                  URLQueryItem(name: "limit", value: "\(AppConfig.Groups.discoverPageSize)"),
                                                  URLQueryItem(name: "lat", value: "52.52"),
                                                  URLQueryItem(name: "lon", value: "13.40")])
        #expect(client.requests[1].queryItems.map(\.name) == ["scope", "q", "limit"])
        #expect(client.requests[2].queryItems.map(\.name) == ["scope"])
    }

    @Test func anEmptyQueryIsNotSent() async throws {
        client.responses = [Page<SportGroup>(items: [])]

        _ = try await repository.groups(in: .discover(query: "", type: nil), cursor: nil, near: nil)

        #expect(client.requests.first?.queryItems.map(\.name) == ["scope", "limit"])
    }

    @Test func groupGetsTheGroupResource() async throws {
        client.responses = [group]

        #expect(try await repository.group(id: "g1") == group)
        #expect(client.requests.first?.method == .get && client.requests.first?.path == "/api/groups/g1")
    }

    @Test func createPostsThePayloadAndUpdatePutsIt() async throws {
        let draft = GroupDraft.fixture()
        client.responses = [group, group]

        _ = try await repository.create(draft)
        _ = try await repository.update(id: "g1", draft)

        #expect(client.requests.map(\.method) == [.post, .put])
        #expect(client.requests.map(\.path) == ["/api/groups", "/api/groups/g1"])
        #expect(client.requests[0].body as? CreateGroupPayload == CreateGroupPayload(draft: draft))
        #expect(client.requests[1].body as? UpdateGroupPayload == UpdateGroupPayload(draft: draft))
    }

    @Test func membershipRoutesUseTheMembersResource() async throws {
        client.responses = [group, group, group, group]

        _ = try await repository.join(id: "g1")
        _ = try await repository.leave(id: "g1")
        _ = try await repository.remove(id: "g1", userID: "u-2")
        _ = try await repository.delete(id: "g1")

        #expect(client.requests.map(\.method) == [.post, .delete, .delete, .delete])
        #expect(client.requests.map(\.path) == ["/api/groups/g1/members", "/api/groups/g1/members/u-1",
                                                "/api/groups/g1/members/u-2", "/api/groups/g1"])
        #expect(client.requests.allSatisfy { $0.body == nil && $0.queryItems.isEmpty })
    }

    /// Leaving is a delete of the caller's own row; without a caller there is nothing to delete and no request.
    @Test func leaveWithoutACallerFailsBeforeAnyRequest() async {
        identity.currentUserID = nil
        await #expect(throws: AppError.notAMember) { try await repository.leave(id: "g1") }
        #expect(client.requests.isEmpty)
    }

    @Test func setRolePutsTheRoleBody() async throws {
        let member = GroupMember.fixture(role: .admin)
        client.responses = [member]

        #expect(try await repository.setRole(id: "g1", userID: "u-2", .admin) == member)
        let request = try #require(client.requests.first)
        #expect(request.method == .put && request.path == "/api/groups/g1/members/u-2")
        #expect(request.body as? RoleChangePayload == RoleChangePayload(role: .admin))
    }

    @Test func rostersUnwrapTheItemsAndUnbanDeletesTheBan() async throws {
        let member = GroupMember.fixture()
        client.responses = [Page(items: [member]), Page(items: [member.withRole(.banned)]), UnbanReceipt(unbanned: true)]

        #expect(try await repository.members(id: "g1") == [member])
        #expect(try await repository.bans(id: "g1") == [member.withRole(.banned)])
        try await repository.unban(id: "g1", userID: "u-2")

        #expect(client.requests.map(\.method) == [.get, .get, .delete])
        #expect(client.requests.map(\.path) == ["/api/groups/g1/members", "/api/groups/g1/bans", "/api/groups/g1/bans/u-2"])
    }

    @Test(arguments: codeCases)
    func backendCodesMapToAppErrors(code: String, expected: AppError) async {
        client.error = APIError.http(status: 409, body: APIErrorBody(code: code, message: "m"))

        await #expect(throws: expected) { try await repository.join(id: "g1") }
    }

    /// Both id conflicts mean the group behind the id may exist: the generic creation failure triggers the refetch.
    @Test func idConflictsAndUnnamedCreateFailuresBecomeGroupCreationFailed() async {
        let coded = ["GROUP_ID_TAKEN", "GROUP_ID_REUSED", "VALIDATION_FAILED"].map {
            APIError.http(status: 409, body: APIErrorBody(code: $0, message: "m"))
        }
        for error in coded + Self.otherFailures {
            client.error = error
            await #expect(throws: AppError.groupCreationFailed) { try await repository.create(.fixture()) }
        }
    }

    @Test func otherFailuresOnReadsBecomeGroupsUnavailableAndOnWritesGroupActionFailed() async {
        for error in Self.otherFailures {
            client.error = error
            await #expect(throws: AppError.groupsUnavailable) { try await repository.groups(in: .mine, cursor: nil, near: nil) }
            await #expect(throws: AppError.groupsUnavailable) { try await repository.group(id: "g1") }
            await #expect(throws: AppError.groupsUnavailable) { try await repository.members(id: "g1") }
            await #expect(throws: AppError.groupActionFailed) { try await repository.join(id: "g1") }
            await #expect(throws: AppError.groupActionFailed) { try await repository.leave(id: "g1") }
            await #expect(throws: AppError.groupActionFailed) { try await repository.unban(id: "g1", userID: "u-2") }
        }
    }

    @Test func statusOnlyFailuresAndTransportKeepTheSharedMapping() async {
        client.error = APIError.http(status: 401, body: nil)
        await #expect(throws: AppError.sessionExpired) { try await repository.groups(in: .mine, cursor: nil, near: nil) }

        client.error = APIError.http(status: 429, body: nil)
        await #expect(throws: AppError.rateLimited(retryAfter: nil)) { try await repository.join(id: "g1") }

        client.error = URLError(.notConnectedToInternet)
        await #expect(throws: AppError.network) { try await repository.group(id: "g1") }

        client.error = URLError(.cancelled)
        await #expect(throws: URLError(.cancelled)) { try await repository.groups(in: .mine, cursor: nil, near: nil) }
    }
}
