import Foundation

/// Reports are accepted and forgotten; blocks are kept in memory for the run.
final class MockModerationRepository: ModerationRepository {
    private var blocked: Set<String> = []
    private let logger: any Logging
    private let now: () -> Date

    init(logger: any Logging, now: @escaping () -> Date = { .now }) {
        self.logger = logger
        self.now = now
    }

    func report(_ report: ReportPayload) async throws -> ReportReceipt {
        logger.info(.groups, "Mock report filed on \(report.targetType.rawValue) \(report.targetId)")
        return ReportReceipt(id: UUID().uuidString.lowercased(), createdAt: now())
    }

    func blocks() async throws -> Set<String> {
        blocked
    }

    func block(userID: String) async throws -> Set<String> {
        guard blocked.contains(userID) || blocked.count < AppConfig.Moderation.maxBlocks else { throw AppError.blockLimitReached }
        blocked.insert(userID)
        return blocked
    }

    func unblock(userID: String) async throws -> Set<String> {
        blocked.remove(userID)
        return blocked
    }
}
