import Foundation
import Testing
@testable import lily

@MainActor
struct RemoteUserRepositoryTests {
    private static let otherFailures: [APIError] = [
        .http(status: 500, body: nil), .http(status: 403, body: nil), .decodingFailed, .notHTTPResponse,
    ]

    private let client = FakeAPIClient()

    private var repository: RemoteUserRepository { RemoteUserRepository(client: client) }

    @Test func profileGetsTheUserResource() async throws {
        let profile = UserProfile.fixture()
        client.responses = [profile]

        #expect(try await repository.profile(userID: "seed-marta") == profile)
        let request = try #require(client.requests.first)
        #expect(request.method == .get && request.path == "/api/users/seed-marta")
        #expect(request.queryItems.isEmpty && request.body == nil)
    }

    @Test func startConversationPostsThePersonsId() async throws {
        let conversation = SportGroup.conversationFixture()
        client.responses = [conversation]

        #expect(try await repository.startConversation(with: "seed-marta") == conversation)
        let request = try #require(client.requests.first)
        #expect(request.method == .post && request.path == "/api/conversations")
        #expect(request.body as? StartConversationPayload == StartConversationPayload(userId: "seed-marta"))
        let encoded = try APIJSONCoding.makeEncoder().encode(StartConversationPayload(userId: "seed-marta"))
        let json = try #require(try JSONSerialization.jsonObject(with: encoded) as? [String: String])
        #expect(json == ["userId": "seed-marta"])
    }

    /// The contract's profile: the shared groups sorted by name, a type only where the group has one.
    @Test func theContractProfileDecodes() throws {
        let profile = try ContractSamples.decode(UserProfile.self, from: ContractSamples.userProfile)

        #expect(profile.userId == "seed-marta" && profile.displayName == "Marta")
        #expect(profile.sharedGroups.map(\.name) == ["Kreuzberg Kickers", "Sunday Padel Crew"])
        #expect(profile.sharedGroups.map(\.type) == [.football, nil])
        #expect(profile.sharedGroups.map(\.visibility) == [.public, .private])
        #expect(profile.sharedGroups.map(\.memberCount) == [34, 6])
        let own = try ContractSamples.decode(UserProfile.self, from: ContractSamples.ownProfileWithoutGroups)
        #expect(own.sharedGroups.isEmpty)
    }

    /// A summary's row links through the shared `EventGroupRef` destination and captions like a group's own row.
    @Test func aSummaryBecomesALiveGroupRefAndCaptionsLikeAGroup() throws {
        let summary = try ContractSamples.decode(UserProfile.self, from: ContractSamples.userProfile).sharedGroups[0]

        #expect(summary.ref == EventGroupRef(id: summary.id, name: "Kreuzberg Kickers", visibility: .public, isDeleted: false))
        #expect(summary.ref.isLinkable)
        #expect(summary.caption == "34 members · Football")
        #expect(GroupSummary(.fixture(id: "g", name: "Spree Volley", type: .volleyball, memberCount: 12)).caption
                == "12 members · Volleyball")
    }

    /// The conversation is a `Group` of kind `direct` with the other person on it, otherwise shaped like any group.
    @Test func theContractConversationDecodesAsAGroupTheCallerIsIn() throws {
        let conversation = try ContractSamples.decode(SportGroup.self, from: ContractSamples.conversation)

        #expect(conversation.isDirect && conversation.counterpart?.userId == "seed-marta")
        #expect(conversation.name == "Marta" && conversation.visibility == .private)
        #expect(conversation.memberCount == 2 && conversation.maxMembers == 2 && conversation.channelEpoch == 1)
        #expect(conversation.role == .member && conversation.isMember)
        #expect(!conversation.membersCanCreateEvents && !conversation.membersCanInvite)
    }

    @Test func backendCodesMapToAppErrors() async {
        let cases: [(code: String, expected: AppError)] = [
            ("USER_NOT_FOUND", .userNotFound), ("CONVERSATION_LIMIT", .conversationLimit), ("TRY_AGAIN", .tryAgain),
            ("TERMS_REQUIRED", .termsRequired), ("ACCOUNT_SUSPENDED", .accountSuspended),
            ("VALIDATION_FAILED", .conversationFailed),
        ]
        for (code, expected) in cases {
            client.error = APIError.http(status: 409, body: APIErrorBody(code: code, message: "m"))
            await #expect(throws: expected, "\(code)") { try await repository.startConversation(with: "seed-marta") }
        }
        client.error = APIError.http(status: 404, body: APIErrorBody(code: "USER_NOT_FOUND", message: "m"))
        await #expect(throws: AppError.userNotFound) { try await repository.profile(userID: "nobody") }
    }

    @Test func otherFailuresBecomeTheCallersFallback() async {
        for error in Self.otherFailures {
            client.error = error
            await #expect(throws: AppError.profileUnavailable) { try await repository.profile(userID: "seed-marta") }
            await #expect(throws: AppError.conversationFailed) { try await repository.startConversation(with: "seed-marta") }
        }
    }

    @Test func statusOnlyFailuresAndTransportKeepTheSharedMapping() async {
        client.error = APIError.http(status: 401, body: nil)
        await #expect(throws: AppError.sessionExpired) { try await repository.profile(userID: "seed-marta") }

        client.error = APIError.http(status: 429, body: nil)
        await #expect(throws: AppError.rateLimited(retryAfter: nil)) { try await repository.startConversation(with: "u-2") }

        client.error = URLError(.notConnectedToInternet)
        await #expect(throws: AppError.network) { try await repository.profile(userID: "seed-marta") }

        client.error = URLError(.cancelled)
        await #expect(throws: URLError(.cancelled)) { try await repository.startConversation(with: "seed-marta") }
    }
}
