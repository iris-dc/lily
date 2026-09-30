import Foundation
@testable import lily

/// Scriptable `EventRepository`: answers from `result`, can hold requests, and records every call.
@MainActor
final class FakeEventRepository: EventRepository {
    var result: Result<[SportEvent], AppError> = .success([])
    /// Thrown instead of `result` when set, for errors that are not `AppError` (such as `CancellationError`).
    var thrownError: (any Error)?
    /// While true, every request records its call and then suspends until `releaseRequests()`.
    var holdsRequests: Bool {
        get { hold.isEnabled }
        set { hold.isEnabled = newValue }
    }
    /// Thrown by `join` and `leave` when set; otherwise they answer with the event from `result`, adjusted.
    var participationError: (any Error)?
    /// Thrown by the next `join` or `leave` only, ahead of `participationError`: for answers that change between
    /// attempts (a `TRY_AGAIN`, then success).
    var nextParticipationError: (any Error)?
    /// Thrown by `create` when set; otherwise the draft becomes an event hosted by `hostUserID`, joined, 1 of N.
    var createError: (any Error)?
    var hostUserID = "host"
    /// Answered by `participants(eventId:)`.
    var participantsResult: Result<[EventParticipant], AppError> = .success([])
    private let hold = RequestHold()
    private(set) var requestedScopes: [EventScope] = []
    /// The position each `events(in:near:)` carried, `nil` included, in call order.
    private(set) var requestedPositions: [Coordinate?] = []
    private(set) var fetchedEventIDs: [String] = []
    private(set) var participantsRequests: [String] = []
    private(set) var joinedEventIDs: [String] = []
    private(set) var leftEventIDs: [String] = []
    private(set) var createdDrafts: [EventDraft] = []

    func events(in scope: EventScope, near position: Coordinate?) async throws -> [SportEvent] {
        requestedScopes.append(scope)
        requestedPositions.append(position)
        await hold.wait()
        if let thrownError { throw thrownError }
        return try result.get()
    }

    /// Answers from `result` like `events(in:near:)`, so a test sets the "server state" once for both.
    func event(id: String) async throws -> SportEvent {
        fetchedEventIDs.append(id)
        await hold.wait()
        if let thrownError { throw thrownError }
        return try stored(id)
    }

    func participants(eventId: String) async throws -> [EventParticipant] {
        participantsRequests.append(eventId)
        await hold.wait()
        return try participantsResult.get()
    }

    func join(eventId: String) async throws -> SportEvent {
        joinedEventIDs.append(eventId)
        return try await participationResult(for: eventId, delta: 1, isJoined: true)
    }

    func leave(eventId: String) async throws -> SportEvent {
        leftEventIDs.append(eventId)
        return try await participationResult(for: eventId, delta: -1, isJoined: false)
    }

    func create(_ draft: EventDraft) async throws -> SportEvent {
        createdDrafts.append(draft)
        await hold.wait()
        if let createError { throw createError }
        return draft.makeEvent(hostUserId: hostUserID,
                               hostName: TestFixtures.user.displayName,
                               coordinate: draft.coordinate ?? AppConfig.Location.mockCenter)
    }

    /// Lets every held request through and stops holding new ones.
    func releaseRequests() {
        hold.release()
    }

    private func participationResult(for eventId: String, delta: Int, isJoined: Bool) async throws -> SportEvent {
        await hold.wait()
        if let error = nextParticipationError {
            nextParticipationError = nil
            throw error
        }
        if let participationError { throw participationError }
        let event = try stored(eventId)
        return event.updatingParticipation(count: event.participantCount + delta, isJoined: isJoined)
    }

    private func stored(_ eventId: String) throws -> SportEvent {
        guard let event = try result.get().first(where: { $0.id == eventId }) else { throw AppError.eventNotFound }
        return event
    }
}
