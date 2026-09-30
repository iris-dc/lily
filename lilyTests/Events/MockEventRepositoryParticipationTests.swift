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

    /// The host leads, the others are roster names (so their profiles resolve), the caller closes the list as "You" when
    /// they joined, and the rows count what the event counts.
    @Test func participantsListTheHostFirstAndTheCallerAsYouWhenJoined() async throws {
        let signedIn = MockEventRepository(now: .now,
                                           count: AppConfig.Events.mockFeedSize,
                                           identity: FakeIdentityProvider(currentUserID: TestFixtures.user.id),
                                           logger: SpyLogger())
        let events = try await signedIn.events(in: .upcoming, near: nil)
        let joined = try #require(events.first { $0.participates })
        let open = try #require(events.first { !$0.participates && $0.participantCount > 1 })

        let joinedRows = try await signedIn.participants(eventId: joined.id)
        #expect(joinedRows.count == joined.participantCount)
        #expect(joinedRows.first == EventParticipant(userId: MockGroupFixtures.memberID(for: joined.hostName),
                                                     displayName: joined.hostName,
                                                     joinedAt: joinedRows[0].joinedAt,
                                                     isHost: true))
        #expect(joinedRows.last?.userId == TestFixtures.user.id && joinedRows.last?.displayName == "You")
        #expect(joinedRows.dropFirst().allSatisfy { !$0.isHost })
        #expect(joinedRows.dropFirst().dropLast().allSatisfy { MockEventFixtures.participantNames.contains($0.displayName) })
        #expect(Set(joinedRows.map(\.userId)).count == joinedRows.count, "nobody is listed twice")

        let openRows = try await signedIn.participants(eventId: open.id)
        #expect(openRows.count == open.participantCount && openRows.first?.isHost == true)
        #expect(!openRows.contains { $0.userId == TestFixtures.user.id })
        #expect(try await signedIn.participants(eventId: open.id) == openRows, "the same list on every call")
        await #expect(throws: AppError.eventNotFound) { try await signedIn.participants(eventId: "missing") }
    }

    /// A game the caller created is theirs: one "You" row, the host's, never a second one.
    @Test func aCreatedGameListsTheCallerAsItsHostOnce() async throws {
        let signedIn = MockEventRepository(now: .now,
                                           count: 1,
                                           identity: FakeIdentityProvider(currentUserID: TestFixtures.user.id),
                                           logger: SpyLogger())
        let created = try await signedIn.create(.fixture())

        let rows = try await signedIn.participants(eventId: created.id)

        let expected = EventParticipant(userId: TestFixtures.user.id,
                                        displayName: "You",
                                        joinedAt: rows[0].joinedAt,
                                        isHost: true)
        #expect(rows == [expected])
    }

    @Test func eventByIdReturnsTheStoredEvent() async throws {
        let first = try #require(try await repository.events(in: .upcoming, near: nil).first)

        #expect(try await repository.event(id: first.id) == first)
    }
}
