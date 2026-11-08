import Foundation

/// The caller's own account as the backend sees it: operator status, where live chat connects, and the account's own
/// deletion.
protocol MeRepository {
    func me() async throws -> Account
    /// The advisory preview of what deleting the account touches; the backend re-derives everything on execute.
    func deletionPlan() async throws -> DeletionPlan
    /// Asks the backend to delete the account. Asynchronous-accepted: a return means the deletion job is claimed,
    /// first call and replays alike; once the job completed the backend answers 401 (`.sessionExpired`), which
    /// callers treat as landed (`DeletionSettle.isLanded`).
    func deleteAccount() async throws
}
