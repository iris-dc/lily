import Foundation
import Testing
@testable import lily

@MainActor
struct MockMeAndModerationRepositoryTests {
    private let identity = FakeIdentityProvider(currentUserID: MockUsers.user(for: .apple).id)
    private let logger = SpyLogger()

    @Test func theAppleTesterIsAnOperatorWithTheTermsAccepted() async throws {
        let repository = MockMeRepository(identity: identity, logger: logger)

        let account = try await repository.me()
        #expect(account.userId == identity.currentUserID && account.isOperator && account.termsAccepted)
        #expect(account.realtimeEndpoint == nil && account.attachmentsEnabled, "the mock store stands in for the bucket")

        identity.currentUserID = "mock-google"
        #expect(try await repository.me().isOperator == false)

        identity.currentUserID = nil
        await #expect(throws: AppError.sessionExpired) { try await repository.me() }
    }

    @Test func termsAcceptanceEchoesTheVersion() async throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let repository = MockMeRepository(identity: identity, logger: logger) { now }

        #expect(try await repository.acceptTerms(version: 3) == TermsAcceptance(acceptedTermsVersion: 3, acceptedTermsAt: now))
    }

    @Test func blocksAreKeptAndCapped() async throws {
        let repository = MockModerationRepository(logger: logger)

        #expect(try await repository.blocks().isEmpty)
        #expect(try await repository.block(userID: "u-2") == ["u-2"])
        #expect(try await repository.block(userID: "u-2") == ["u-2"])
        #expect(try await repository.unblock(userID: "u-2").isEmpty)

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
