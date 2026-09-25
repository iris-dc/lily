import Foundation
import Testing
@testable import lily

@MainActor
struct RemoteModerationRepositoryTests {
    private let client = FakeAPIClient()

    private var repository: RemoteModerationRepository { RemoteModerationRepository(client: client) }

    @Test func reportPostsTheTargetReasonAndTrimmedComment() async throws {
        let receipt = ReportReceipt(id: "r1", createdAt: .now)
        client.responses = [receipt]
        let payload = ReportPayload(target: .message(id: "m1", groupID: "g1"), reason: .spam, comment: "  Sells things  ")

        #expect(try await repository.report(payload) == receipt)
        let request = try #require(client.requests.first)
        #expect(request.method == .post && request.path == "/api/reports")
        #expect(request.body as? ReportPayload == payload)
        let data = try APIJSONCoding.makeEncoder().encode(payload)
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: String])
        #expect(json == ["targetType": "message", "targetId": "m1", "groupId": "g1", "reason": "spam", "comment": "Sells things"])
    }

    /// A blank comment and a user target's missing group are left out, never sent as `null`.
    @Test func absentReportFieldsAreLeftOut() throws {
        let payload = ReportPayload(target: .user(id: "u-2"), reason: .other, comment: "   ")
        let data = try APIJSONCoding.makeEncoder().encode(payload)
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: String])

        #expect(json == ["targetType": "user", "targetId": "u-2", "reason": "other"])
        #expect(ReportTarget.group(id: "g1").groupID == "g1")
    }

    @Test func blockRoutesAnswerTheWholeListAsASet() async throws {
        client.responses = [BlockedUsers(blockedUserIds: ["u-7"]), BlockedUsers(blockedUserIds: ["u-7", "u-9"]),
                            BlockedUsers(blockedUserIds: ["u-9"])]

        #expect(try await repository.blocks() == ["u-7"])
        #expect(try await repository.block(userID: "u-9") == ["u-7", "u-9"])
        #expect(try await repository.unblock(userID: "u-7") == ["u-9"])

        #expect(client.requests.map(\.method) == [.get, .put, .delete])
        #expect(client.requests.map(\.path) == ["/api/blocks", "/api/blocks/u-9", "/api/blocks/u-7"])
        #expect(client.requests.allSatisfy { $0.body == nil })
    }

    @Test func moderationCodesMapToTheirOwnErrors() async {
        client.error = APIError.http(status: 409, body: APIErrorBody(code: "BLOCK_LIMIT", message: "m"))
        await #expect(throws: AppError.blockLimitReached) { try await repository.block(userID: "u-9") }

        let report = ReportPayload(target: .user(id: "x"), reason: .spam)
        client.error = APIError.http(status: 404, body: APIErrorBody(code: "USER_NOT_FOUND", message: "m"))
        await #expect(throws: AppError.userNotFound) { try await repository.report(report) }

        client.error = APIError.http(status: 500, body: nil)
        await #expect(throws: AppError.reportFailed) { try await repository.report(report) }
        await #expect(throws: AppError.unknown) { try await repository.blocks() }
    }
}
