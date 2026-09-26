import Foundation
import Testing
@testable import lily

@MainActor
struct RemoteInviteRepositoryTests {
    private let client = FakeAPIClient()
    private let invite = Invite.fixture()
    private let code = InviteCode(AppConfig.Groups.mockInviteCode)!

    private var repository: RemoteInviteRepository { RemoteInviteRepository(client: client) }

    @Test func createPostsTheOptionsToTheGroupsInvites() async throws {
        client.responses = [invite]
        let options = InviteOptions(maxUses: 10, expiresInDays: 30)

        #expect(try await repository.create(groupID: "g1", options: options) == invite)
        let request = try #require(client.requests.first)
        #expect(request.method == .post && request.path == "/api/groups/g1/invites")
        #expect(request.body as? InviteOptions == options)
    }

    @Test func theDefaultOptionsAreUnlimitedForTheDefaultDays() throws {
        let options = InviteOptions()
        #expect(options.maxUses == 0 && options.expiresInDays == AppConfig.Groups.inviteDefaultDays)
        let data = try APIJSONCoding.makeEncoder().encode(options)
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Int])
        #expect(json == ["maxUses": 0, "expiresInDays": AppConfig.Groups.inviteDefaultDays])
    }

    @Test func listUnwrapsTheItemsAndRevokeDeletesByHandle() async throws {
        client.responses = [Page(items: [invite]), invite.revoked(at: .now)]

        #expect(try await repository.list(groupID: "g1") == [invite])
        #expect(try await repository.revoke(groupID: "g1", inviteID: invite.inviteId).isRevoked)

        #expect(client.requests.map(\.method) == [.get, .delete])
        #expect(client.requests.map(\.path) == ["/api/groups/g1/invites", "/api/groups/g1/invites/\(invite.inviteId)"])
    }

    /// The code is a capability: it travels in the body, and the path the client logs never contains it.
    @Test func previewAndRedeemPostTheCodeInTheBodyNeverInThePath() async throws {
        let preview = try ContractSamples.decode(InvitePreview.self, from: ContractSamples.invitePreview)
        let group = SportGroup.fixture()
        client.responses = [preview, group]

        #expect(try await repository.preview(code: code) == preview)
        #expect(try await repository.redeem(code: code) == group)

        #expect(client.requests.map(\.method) == [.post, .post])
        #expect(client.requests.map(\.path) == ["/api/invites/preview", "/api/invites/redeem"])
        for request in client.requests {
            #expect(!request.path.contains(code.value) && request.queryItems.isEmpty)
            #expect(request.body as? InviteCodePayload == InviteCodePayload(code))
        }
    }

    @Test func inviteCodesMapToTheirOwnErrors() async {
        client.error = APIError.http(status: 404, body: APIErrorBody(code: "INVITE_INVALID", message: "m"))
        await #expect(throws: AppError.inviteInvalid) { try await repository.redeem(code: code) }

        client.error = APIError.http(status: 409, body: APIErrorBody(code: "INVITE_EXPIRED", message: "m"))
        await #expect(throws: AppError.inviteExpired) { try await repository.preview(code: code) }

        client.error = APIError.http(status: 409, body: APIErrorBody(code: "INVITE_LIMIT", message: "m"))
        await #expect(throws: AppError.inviteLimitReached) {
            try await repository.create(groupID: "g1", options: InviteOptions())
        }

        client.error = APIError.http(status: 403, body: APIErrorBody(code: "BANNED", message: "m"))
        await #expect(throws: AppError.bannedFromGroup) { try await repository.redeem(code: code) }
    }

    /// An unnamed preview failure is a failed check, not a verdict on the code (only `INVITE_INVALID` is); an unnamed
    /// redeem or create is a failed group action.
    @Test func unnamedFailuresFallBackPerRoute() async {
        client.error = APIError.http(status: 500, body: nil)
        await #expect(throws: AppError.inviteUnavailable) { try await repository.preview(code: code) }
        await #expect(throws: AppError.groupActionFailed) { try await repository.redeem(code: code) }
        await #expect(throws: AppError.groupActionFailed) { try await repository.create(groupID: "g1", options: InviteOptions()) }
        await #expect(throws: AppError.groupActionFailed) { try await repository.revoke(groupID: "g1", inviteID: "i") }
        await #expect(throws: AppError.groupsUnavailable) { try await repository.list(groupID: "g1") }
    }
}
