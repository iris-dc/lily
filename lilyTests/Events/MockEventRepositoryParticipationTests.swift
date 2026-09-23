import Foundation
import Testing
@testable import lily

/// The mock joins and leaves in memory so previews, UI tests and `-mock-events` behave like the backend.
@MainActor
struct MockEventRepositoryParticipationTests {
    private let repository = MockEventRepository(now: .now,
                                                 count: AppConfig.Events.mockFeedSize,
                                                 identity: FakeIdentityProvider(),
                                                 logger: SpyLogger())

    @Test func joinedEventsAlwaysHaveAParticipant() async throws {
        let joined = try await repository.events(in: .joined, near: nil)
        #expect(!joined.isEmpty)
        #expect(joined.allSatisfy { $0.participates && $0.participantCount >= 1 })
    }

    @Test func joinAddsTheCallerAndLeaveRemovesThem() async throws {
        let events = try await repository.events(in: .upcoming, near: nil)
        let open = try #require(events.first { !$0.participates && !$0.isFull })

        let joined = try await repository.join(eventId: open.id)
        #expect(joined.participates)
        #expect(joined.participantCount == open.participantCount + 1)
        #expect(try await repository.event(id: open.id) == joined)
        #expect(try await repository.events(in: .joined, near: nil).contains(joined))
        #expect(try await repository.events(in: .upcoming, near: nil).contains(joined))

        let left = try await repository.leave(eventId: open.id)
        #expect(!left.participates)
        #expect(left.participantCount == open.participantCount)
        let joinedAfterLeaving = try await repository.events(in: .joined, near: nil)
        #expect(!joinedAfterLeaving.contains { $0.id == open.id })
    }

    @Test func joinRejectsFullEventsAndRepeatedJoins() async throws {
        let events = try await repository.events(in: .upcoming, near: nil)
        let fullWithoutTheCaller = events.filter { $0.isFull && !$0.participates }
        let full = try #require(fullWithoutTheCaller.first)
        let joined = try #require(events.first { $0.participates })

        await #expect(throws: AppError.eventFull) { try await repository.join(eventId: full.id) }
        await #expect(throws: AppError.alreadyJoined) { try await repository.join(eventId: joined.id) }
    }

    @Test func leaveRejectsNonParticipantsAndUnknownIdsAreNotFound() async throws {
        let events = try await repository.events(in: .upcoming, near: nil)
        let open = try #require(events.first { !$0.participates })

        await #expect(throws: AppError.notAParticipant) { try await repository.leave(eventId: open.id) }
        await #expect(throws: AppError.eventNotFound) { try await repository.join(eventId: "missing") }
        await #expect(throws: AppError.eventNotFound) { try await repository.leave(eventId: "missing") }
        await #expect(throws: AppError.eventNotFound) { try await repository.event(id: "missing") }
    }

    @Test func eventByIdReturnsTheStoredEvent() async throws {
        let first = try #require(try await repository.events(in: .upcoming, near: nil).first)

        #expect(try await repository.event(id: first.id) == first)
    }
}
