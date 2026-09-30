import Foundation
import Observation

/// Owns the event shown on the detail screen, the join/leave action on it and, for signed-in callers, who is in.
@Observable
final class EventDetailViewModel {
    private(set) var event: SportEvent
    private(set) var isBusy = false
    /// Who is in, the host first; empty for guests, who see the count only.
    private(set) var participants: [EventParticipant] = []
    private(set) var isLoadingParticipants = false

    private let repository: any EventRepository
    private let identity: any IdentityProvider
    private let errorCenter: ErrorCenter
    private let recorder: any InteractionRecorder
    private let logger: any Logging
    private let tryAgainDelay: Duration
    private let now: () -> Date
    private let onChange: @MainActor (SportEvent) -> Void
    private var hasRecordedView = false

    init(event: SportEvent,
         repository: any EventRepository,
         identity: any IdentityProvider,
         errorCenter: ErrorCenter,
         recorder: any InteractionRecorder,
         logger: any Logging,
         tryAgainDelay: Duration = AppConfig.API.tryAgainDelay,
         now: @escaping () -> Date = { .now },
         onChange: @escaping @MainActor (SportEvent) -> Void) {
        self.event = event
        self.repository = repository
        self.identity = identity
        self.errorCenter = errorCenter
        self.recorder = recorder
        self.logger = logger
        self.tryAgainDelay = tryAgainDelay
        self.now = now
        self.onChange = onChange
    }

    var participation: Participation {
        Participation(event: event, userID: identity.currentUserID)
    }

    /// The host, and nobody else, may change the game; the detail shows Edit for them.
    var canEdit: Bool { participation == .hosting }

    /// Names are members-level information, like a roster: shown to signed-in callers only.
    var showsParticipants: Bool { identity.currentUserID != nil }

    /// The host's profile, when the caller may open it: signed in, the host known, and not the caller themselves.
    var hostProfile: UserProfileDestination? {
        guard let hostUserId = event.hostUserId, let caller = identity.currentUserID, hostUserId != caller else { return nil }
        return UserProfileDestination(userId: hostUserId, displayName: event.hostName)
    }

    func isSelf(_ participant: EventParticipant) -> Bool {
        participant.userId == identity.currentUserID
    }

    /// On appear and after every join, leave or refetch; a failure reaches the popup and keeps the last list.
    func loadParticipants() async {
        guard showsParticipants else { return }
        isLoadingParticipants = true
        defer { isLoadingParticipants = false }
        do {
            participants = try await repository.participants(eventId: event.id)
        } catch {
            guard !AppError.isCancellation(error) else { return }
            logger.warning(.events, "Loading participants of event \(event.id) failed: \(error)")
            errorCenter.report(error)
        }
    }

    /// One view per screen instance, however often the view's task restarts (a sheet over it comes and goes).
    func recordViewed() {
        guard !hasRecordedView else { return }
        hasRecordedView = true
        recorder.record(.viewed(event, at: now()))
    }

    func join() async {
        await update("Join", wantsToParticipate: true) { try await repository.join(eventId: event.id) }
    }

    func leave() async {
        await update("Leave", wantsToParticipate: false) { try await repository.leave(eventId: event.id) }
    }

    /// One change at a time. The server's answer replaces the event and goes to `onChange`, so the list behind this
    /// screen is right on the way back without a reload. A refusal because the event moved on is shown, but only
    /// after the event on screen has been brought up to date, so the popup and the numbers agree. A failure that
    /// leaves the outcome unknown is shown only when the refetched event does not already show what the user asked
    /// for: Laurel commits a join before it reads the event back, so the write may have landed, and a popup saying
    /// otherwise would only send the user into an "already joined" refusal.
    private func update(_ action: String, wantsToParticipate: Bool, _ change: () async throws -> SportEvent) async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            let updated = try await LostRace.attemptTwice(delay: tryAgainDelay, onRetry: { logRetry(action) }, change)
            apply(updated)
            logSuccess(action, updated)
            await loadParticipants()
        } catch {
            guard !AppError.isCancellation(error) else { return }
            logFailure(action, error)
            let fresh = await refreshAfterFailure(error)
            if let fresh, Self.landed(despite: error, fresh: fresh, wantsToParticipate: wantsToParticipate) {
                logger.info(.events, "\(action) landed for event \(fresh.id) despite \(error); nothing to report")
                return
            }
            errorCenter.report(error)
        }
    }

    private func logRetry(_ action: String) {
        logger.info(.events, "\(action) lost a race for event \(event.id); retrying once")
    }

    private func logSuccess(_ action: String, _ updated: SportEvent) {
        logger.info(.events, "\(action) succeeded for event \(updated.id): \(updated.participantCount)/\(updated.capacity)")
        if updated.isFull { logger.info(.events, "Capacity reached for event \(updated.id)") }
    }

    /// An unknown outcome (never a refusal) whose refetch already shows the change the user asked for.
    private static func landed(despite error: any Error, fresh: SportEvent, wantsToParticipate: Bool) -> Bool {
        guard let appError = error as? AppError, !appError.isParticipationConflict else { return false }
        return fresh.participates == wantsToParticipate
    }

    /// A refusal is an expected product state (the event moved on) and stays a warning; anything else is an error.
    private func logFailure(_ action: String, _ error: any Error) {
        let message = "\(action) failed for event \(event.id): \(error)"
        if let appError = error as? AppError, appError.isParticipationConflict {
            logger.warning(.events, message)
        } else {
            logger.error(.events, message)
        }
    }

    /// The server refused because the event is not what the screen shows (any of the 409s, or a failure that leaves
    /// the outcome unknown: the write may have committed before the answer was lost). Fetching it again fixes the
    /// numbers here and, through `onChange`, in the lists behind; a failed fetch leaves things as they are, the
    /// popup still explains the refusal. Returns the fresh event when there is one.
    private func refreshAfterFailure(_ error: any Error) async -> SportEvent? {
        guard let appError = error as? AppError, appError.needsRefresh else { return nil }
        guard let fresh = try? await repository.event(id: event.id) else {
            logger.warning(.events, "Could not refresh event \(event.id) after \(appError)")
            return nil
        }
        apply(fresh)
        logger.info(.events, "Refreshed event \(event.id) after \(appError): \(fresh.participantCount)/\(fresh.capacity)")
        await loadParticipants()
        return fresh
    }

    /// Takes the event as the edit sheet saved it, so the detail and the list behind it show the change at once.
    func accept(_ updated: SportEvent) {
        apply(updated)
    }

    private func apply(_ updated: SportEvent) {
        event = updated
        onChange(updated)
    }
}

private extension AppError {
    /// Refusals (the 409s) that mean the event changed under the caller: expected product states, not failures.
    var isParticipationConflict: Bool {
        switch self {
        case .eventFull, .alreadyJoined, .notAParticipant, .hostCannotLeave, .tryAgain: true
        default: false
        }
    }

    /// Outcomes after which the event's current state is worth another look: a conflict, or a failure that leaves
    /// the outcome unknown (a 500 or a lost connection after the backend may already have committed the change).
    var needsRefresh: Bool {
        isParticipationConflict || self == .participationFailed || self == .network
    }
}
