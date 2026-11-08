import Foundation

/// Answers a signed-in mock user: an operator when signed in as the Apple tester, mirroring the backend's operators
/// group, no realtime endpoint, attachments on (the mock store stands in for the bucket), and the terms stamped
/// accepted, as Laurel stamps them at account creation (owner decision 2026-11-08: agreement is by use).
/// Account deletion rehearses the contract in memory: `deleteAccount()` claims a job (a replay while it runs answers
/// success again), the poll's next `me()` still answers while the job "runs", then the account is deleted and every
/// route throws the tombstone's 401 as `.sessionExpired`, so the delete flow is walkable without a backend.
final class MockMeRepository: MeRepository {
    private enum DeletionProgress: Equatable {
        case idle, running, deleted
    }
    private var deletion: DeletionProgress = .idle
    /// What the preview answers, mirroring the contract's sample: one of each shape, so every summary line can render.
    private static let plan = DeletionPlan(groupsTransferring: 2,
                                           groupsDeleted: 1,
                                           eventsCancelled: 1,
                                           entriesWithdrawn: 3,
                                           tournamentsCancelled: 0)
    private let identity: any IdentityProvider
    private let logger: any Logging

    init(identity: any IdentityProvider, logger: any Logging) {
        self.identity = identity
        self.logger = logger
    }

    func me() async throws -> Account {
        guard let userID = identity.currentUserID else { throw AppError.sessionExpired }
        try settleDeletion()
        logger.debug(.groups, "Mock me served")
        return Account(userId: userID,
                       isOperator: userID == MockUsers.user(for: .apple).id,
                       termsVersion: AppConfig.Moderation.mockTermsVersion,
                       acceptedTermsVersion: AppConfig.Moderation.mockTermsVersion,
                       attachmentsEnabled: true)
    }

    func deletionPlan() async throws -> DeletionPlan {
        guard identity.currentUserID != nil else { throw AppError.sessionExpired }
        try refuseDeleted()
        logger.debug(.groups, "Mock deletion plan served")
        return Self.plan
    }

    func deleteAccount() async throws {
        guard identity.currentUserID != nil else { throw AppError.sessionExpired }
        try refuseDeleted()
        if deletion == .idle {
            deletion = .running
            logger.info(.groups, "Mock account deletion claimed")
        } else {
            logger.info(.groups, "Mock account deletion replayed into the running job")
        }
    }

    /// One read still answers while the job runs (the locked sheet's first poll), then the job has completed: every
    /// later read is the tombstone's 401, which settles the poll as landed.
    private func settleDeletion() throws {
        switch deletion {
        case .idle:
            return
        case .running:
            deletion = .deleted
        case .deleted:
            throw AppError.sessionExpired
        }
    }

    /// The tombstone's categorical 401, which lily maps to `.sessionExpired` before any body is read.
    private func refuseDeleted() throws {
        guard deletion == .deleted else { return }
        logger.info(.groups, "Mock account already deleted: answering the tombstone's 401")
        throw AppError.sessionExpired
    }
}
