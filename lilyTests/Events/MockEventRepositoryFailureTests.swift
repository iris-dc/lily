import Foundation
import Testing
@testable import lily

/// `-mock-events-fail`: the mock refuses its first list load with a network error and answers every later one, so the
/// failed list state and the root popup can be walked without a backend; nothing but the list load is affected.
@MainActor
struct MockEventRepositoryFailureTests {
    private let identity = FakeIdentityProvider(currentUserID: TestFixtures.user.id)
    private let logger = SpyLogger()
    /// Explore lists every fixture but the private group's game.
    private let listedFixtureCount = AppConfig.Events.mockFeedSize - 1

    private func makeRepository(failsFirstLoad: Bool) -> MockEventRepository {
        MockEventRepository(identity: identity, logger: logger, failsFirstLoad: failsFirstLoad)
    }

    @Test func theFirstLoadFailsWithANetworkErrorAndTheSecondAnswersTheFixtures() async throws {
        let repository = makeRepository(failsFirstLoad: true)

        await #expect(throws: AppError.network) { try await repository.events(in: .upcoming, near: nil) }

        #expect(logger.messages(in: .events, at: .warning).count == 1)
        #expect(try await repository.events(in: .upcoming, near: nil).count == listedFixtureCount)
        #expect(try await repository.events(in: .upcoming, near: nil).count == listedFixtureCount)
    }

    @Test func aFailingFirstLoadLeavesTheDetailReadAlone() async throws {
        let repository = makeRepository(failsFirstLoad: true)
        let first = try #require(MockEventFixtures.make(now: .now, count: 1).first)

        let detail = try await repository.event(id: first.id)

        #expect(detail.id == first.id && detail.title == first.title)
        await #expect(throws: AppError.network) { try await repository.events(in: .upcoming, near: nil) }
    }

    @Test func withoutTheFlagNoLoadFails() async throws {
        let repository = makeRepository(failsFirstLoad: false)

        #expect(try await repository.events(in: .upcoming, near: nil).count == listedFixtureCount)
        #expect(logger.messages(in: .events, at: .warning).isEmpty)
    }
}
