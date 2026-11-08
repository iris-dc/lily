import Foundation
import Testing
@testable import lily

@MainActor
struct RemoteMeRepositoryTests {
    private let client = FakeAPIClient()

    private var repository: RemoteMeRepository { RemoteMeRepository(client: client) }

    @Test func meGetsTheMeResource() async throws {
        let account = Account.fixture()
        client.responses = [account]

        #expect(try await repository.me() == account)
        let request = try #require(client.requests.first)
        #expect(request.method == .get && request.path == "/api/me" && request.body == nil && request.queryItems.isEmpty)
    }

    /// This route has no fallback of its own, so a code it does not know is `.unknown`; the shared mapping has its own tests.
    @Test func unnamedFailuresFallBackToUnknown() async {
        client.error = APIError.http(status: 400, body: APIErrorBody(code: "VALIDATION_FAILED", message: "m"))
        await #expect(throws: AppError.unknown) { try await repository.me() }
    }

    @Test func deletionPlanGetsThePreview() async throws {
        let plan = DeletionPlan(groupsTransferring: 2,
                                groupsDeleted: 1,
                                eventsCancelled: 1,
                                entriesWithdrawn: 3,
                                tournamentsCancelled: 0)
        client.responses = [plan]

        #expect(try await repository.deletionPlan() == plan)
        let request = try #require(client.requests.first)
        #expect(request.method == .get && request.path == "/api/me/deletion-plan" && request.body == nil)
    }

    /// `202 Accepted`, empty body, first call and replays alike.
    @Test func deleteAccountDeletesTheMeResource() async throws {
        client.responses = [NoContent()]

        try await repository.deleteAccount()

        let request = try #require(client.requests.first)
        #expect(request.method == .delete && request.path == "/api/me" && request.body == nil)
    }

    @Test func theDeletionRoutesFallBackToTheirOwnErrors() async {
        client.error = APIError.http(status: 500, body: nil)
        await #expect(throws: AppError.deletionPlanUnavailable) { try await repository.deletionPlan() }
        await #expect(throws: AppError.accountDeletionFailed) { try await repository.deleteAccount() }
    }

    /// The tombstone's categorical 401 (`UNAUTHENTICATED`, "This account was deleted") maps to `.sessionExpired`
    /// before the body code is read; `DeletionSettle` treats exactly that as landed.
    @Test func aPostCompletionReplayIsThe401TheFlowTreatsAsLanded() async {
        client.error = APIError.http(status: 401,
                                     body: APIErrorBody(code: "UNAUTHENTICATED", message: "This account was deleted"))

        await #expect(throws: AppError.sessionExpired) { try await repository.deleteAccount() }
    }
}
