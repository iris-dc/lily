import Foundation

/// The answer of `GET /api/me/deletion-plan`: what deleting the account would touch, as five advisory counts for the
/// summary copy (one localized plural line per non-zero count). The execute path re-derives everything per entity, so
/// the preview can be stale by confirm time and the copy frames it as approximate.
nonisolated struct DeletionPlan: Hashable, Codable, Sendable {
    /// Owned groups that would pass to their longest-standing member.
    let groupsTransferring: Int
    /// Owned groups with no eligible member to take them, deleted outright.
    let groupsDeleted: Int
    /// Upcoming games the caller hosts, removed with the players notified.
    let eventsCancelled: Int
    /// Entries in tournaments still taking registrations, withdrawn.
    let entriesWithdrawn: Int
    /// Upcoming tournaments the caller organizes, cancelled.
    let tournamentsCancelled: Int
}

/// The delete flow's inverted success check (the deletion contract): once `DELETE /api/me` was sent, any later
/// account read settles the outcome — a 401 (`.sessionExpired`: lily maps the status before reading any body, and the
/// caller gate categorically refuses deleted accounts) or `USER_NOT_FOUND` means the deletion landed, never a failure.
nonisolated enum DeletionSettle {
    static func isLanded(_ error: AppError) -> Bool {
        error == .sessionExpired || error == .userNotFound
    }
}
