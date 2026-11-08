import Foundation
import Testing
@testable import lily

@MainActor
struct MockMeAndModerationRepositoryTests {
    private let identity = FakeIdentityProvider(currentUserID: MockUsers.user(for: .apple).id)
    private let logger = SpyLogger()

    @Test func theAppleTesterIsAnOperatorWithTheTermsStampedAccepted() async throws {
        let repository = MockMeRepository(identity: identity, logger: logger)

        let account = try await repository.me()
        #expect(account.userId == identity.currentUserID && account.isOperator)
        #expect(account.acceptedTermsVersion == account.termsVersion, "stamped at creation, as Laurel stamps them")
        #expect(account.realtimeEndpoint == nil && account.attachmentsEnabled, "the mock store stands in for the bucket")

        identity.currentUserID = "mock-google"
        #expect(try await repository.me().isOperator == false)

        identity.currentUserID = nil
        await #expect(throws: AppError.sessionExpired) { try await repository.me() }
    }

    /// The mock delete rehearses the contract: a replay while the job runs answers success again, the poll's first
    /// read still answers, then the account is deleted and every route is the tombstone's 401.
    @Test func theMockDeletionRunsTheContractsStateMachine() async throws {
        let repository = MockMeRepository(identity: identity, logger: logger)
        let plan = try await repository.deletionPlan()
        #expect(plan == DeletionPlan(groupsTransferring: 2,
                                     groupsDeleted: 1,
                                     eventsCancelled: 1,
                                     entriesWithdrawn: 3,
                                     tournamentsCancelled: 0),
                "the contract's sample counts")

        try await repository.deleteAccount()
        try await repository.deleteAccount()
        _ = try await repository.me()

        await #expect(throws: AppError.sessionExpired) { try await repository.me() }
        await #expect(throws: AppError.sessionExpired) { try await repository.deleteAccount() }
        await #expect(throws: AppError.sessionExpired) { try await repository.deletionPlan() }
    }

    @Test func blocksAreKeptAndCapped() async throws {
        let repository = MockModerationRepository(logger: logger)

        #expect(try await repository.blocks().isEmpty)
        #expect(try await repository.block(userID: "u-2") == ["u-2"])
        #expect(try await repository.block(userID: "u-2") == ["u-2"])

        for index in 0..<AppConfig.Moderation.maxBlocks {
            _ = try await repository.block(userID: "u-\(index)")
        }
        await #expect(throws: AppError.blockLimitReached) { try await repository.block(userID: "one-too-many") }
        #expect(try await repository.block(userID: "u-1").count == AppConfig.Moderation.maxBlocks, "an existing block is fine")
    }

    @Test func reportsAreAcceptedAndLoggedWithoutText() async throws {
        let repository = MockModerationRepository(logger: logger)

        let report = ReportPayload(target: .message(id: "m1", groupID: "g1"), reason: .spam, comment: "secret")
        let receipt = try await repository.report(report)

        #expect(!receipt.id.isEmpty)
        #expect(logger.messages(in: .groups, at: .info) == ["Mock report filed on message m1"])
    }
}
