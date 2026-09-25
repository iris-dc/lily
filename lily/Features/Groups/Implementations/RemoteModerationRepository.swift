import Foundation

final class RemoteModerationRepository: ModerationRepository {
    private let client: any APIClient

    init(client: any APIClient) {
        self.client = client
    }

    func report(_ report: ReportPayload) async throws -> ReportReceipt {
        let request = APIRequest<ReportReceipt>.post(AppConfig.API.Paths.reports, body: report)
        return try await client.send(request, failingWith: .reportFailed)
    }

    func blocks() async throws -> Set<String> {
        try await blockList(.get(AppConfig.API.Paths.blocks))
    }

    func block(userID: String) async throws -> Set<String> {
        try await blockList(.put(AppConfig.API.Paths.block(userID: userID)))
    }

    func unblock(userID: String) async throws -> Set<String> {
        try await blockList(.delete(AppConfig.API.Paths.block(userID: userID)))
    }

    private func blockList(_ request: APIRequest<BlockedUsers>) async throws -> Set<String> {
        let answer = try await client.send(request, failingWith: .unknown)
        return Set(answer.blockedUserIds)
    }
}
