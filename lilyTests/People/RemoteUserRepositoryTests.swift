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
        let json = try ContractSamples.jsonObject(of: StartConversationPayload(userId: "seed-marta"), as: String.self)
        #expect(json == ["userId": "seed-marta"])
    }

    /// The contract's profile: the bio, the shared groups sorted by name with a type only where the group has one, the
    /// games and tournaments together; a backend without the bio and the history answers none and empty lists.
    @Test func theContractProfileDecodes() throws {
        let profile = try ContractSamples.decode(UserProfile.self, from: ContractSamples.userProfile)

        #expect(profile.userId == "sub-2" && profile.displayName == "Noor")
        #expect(profile.bio == "Padel on Sundays, football when it rains.")
        #expect(profile.sharedGroups.map(\.name) == ["Kreuzberg Kickers", "Sunday Padel Crew"])
        #expect(profile.sharedGroups.map(\.type) == [.football, nil])
        #expect(profile.sharedGroups.map(\.visibility) == [.public, .private])
        #expect(profile.sharedGroups.map(\.memberCount) == [34, 6])
        let game = try #require(profile.sharedEvents.first)
        #expect(profile.sharedEvents.count == 1 && game.id == "e1" && game.title == "Sunset 5-a-side")
        #expect(game.type == .football && game.locationName == "Tempelhofer Feld")
        #expect(game.startsAt == Date(timeIntervalSince1970: 1_790_960_400))
        let cup = try #require(profile.sharedTournaments.first)
        #expect(profile.sharedTournaments.count == 1 && cup.id == "t1" && cup.name == "Kickers Cup")
        #expect(cup.type == .football && cup.status == .registration)
        #expect(cup.startsAt == Date(timeIntervalSince1970: 1_791_108_000))
        let own = try ContractSamples.decode(UserProfile.self, from: ContractSamples.ownProfileWithoutGroups)
        #expect(own.bio == nil && own.sharedGroups.isEmpty && own.sharedEvents.isEmpty && own.sharedTournaments.isEmpty)
    }

    /// A game's row captions the sport, the day and the place; a tournament's the sport, the status and the day, and
    /// links to the tournament by id and name alone, the detail fetching the rest.
    @Test func theHistoryRowsCaptionAndLinkFromTheSummaries() {
        let day = EventSummary.fixture.startsAt.formatted(LilyTheme.DateStyles.date)
        #expect(EventSummary.fixture.caption == "Football · \(day) · Tempelhofer Feld")
        let cupDay = TournamentSummary.fixture.startsAt.formatted(LilyTheme.DateStyles.date)
        #expect(TournamentSummary.fixture.caption == "Football · \(TournamentStatus.registration.displayName) · \(cupDay)")
        #expect(TournamentSummary.fixture.destination == TournamentDestination(id: "t1", name: "Kickers Cup"))
        #expect(TournamentSummary.fixture.destination.preview == nil)
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

    /// Only the codes this route maps itself; the shared mapping of `send(_:failingWith:)` has tests of its own.
    @Test func backendCodesMapToAppErrors() async {
        let cases: [(code: String, expected: AppError)] = [
            ("CONVERSATION_LIMIT", .conversationLimit), ("VALIDATION_FAILED", .conversationFailed),
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
}
