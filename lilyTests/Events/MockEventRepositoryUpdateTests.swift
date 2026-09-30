import Foundation
import Testing
@testable import lily

/// The mock edits in memory the way the backend does: the host alone, never below the people already in.
@MainActor
struct MockEventRepositoryUpdateTests {
    private let identity = FakeIdentityProvider(currentUserID: TestFixtures.user.id)
    private let repository: MockEventRepository

    init() {
        repository = MockEventRepository(now: .now, count: AppConfig.Events.mockFeedSize, identity: identity, logger: SpyLogger())
    }

    @Test func theHostUpdatesTheirOwnGameEverywhereItIsListed() async throws {
        let created = try await repository.create(.fixture())
        var draft = EventDraft(editing: created)
        draft.title = "Retitled"
        draft.capacity = 12

        let updated = try await repository.update(id: created.id, draft)

        #expect(updated.title == "Retitled" && updated.capacity == 12)
        #expect(updated.hostUserId == TestFixtures.user.id && updated.participantCount == 1 && updated.participates)
        #expect(try await repository.event(id: created.id) == updated)
        #expect(try await repository.events(in: .joined, near: nil).contains(updated))
    }

    /// The fixtures have no host id, so nobody hosts them: like the backend, the mock refuses anyone but the host.
    @Test func someoneElsesGameCannotBeEdited() async throws {
        let fixture = try #require(try await repository.events(in: .upcoming, near: nil).first)

        await #expect(throws: AppError.notHost) {
            try await repository.update(id: fixture.id, EventDraft(editing: fixture))
        }
    }

    @Test func fewerSpotsThanPeopleInIsRefused() async throws {
        let created = try await repository.create(.fixture())
        var draft = EventDraft(editing: created)
        draft.capacity = 0

        await #expect(throws: AppError.capacityTooLow) { try await repository.update(id: created.id, draft) }
        #expect(try await repository.event(id: created.id) == created)
    }

    @Test func anUnknownGameIsNotFound() async {
        await #expect(throws: AppError.eventNotFound) {
            try await repository.update(id: "nope", .fixture())
        }
    }
}
