import Foundation

/// Reports and blocks. The block routes answer the caller's whole list, so callers replace, never merge.
protocol ModerationRepository {
    func report(_ report: ReportPayload) async throws -> ReportReceipt
    func blocks() async throws -> Set<String>
    func block(userID: String) async throws -> Set<String>
    func unblock(userID: String) async throws -> Set<String>
}
