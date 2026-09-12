import Foundation
import Observation

/// Owns the event shown on the detail screen and the join/leave action on it.
@Observable
final class EventDetailViewModel {
    private(set) var event: SportEvent
    private(set) var isBusy = false

    private let repository: any EventRepository
    private let identity: any IdentityProvider
    private let errorCenter: ErrorCenter
    private let logger: any Logging
    private let tryAgainDelay: Duration
    private let onChange: @MainActor (SportEvent) -> Void

    init(event: SportEvent,
         repository: any EventRepository,
         identity: any IdentityProvider,
         errorCenter: ErrorCenter,
         logger: any Logging,
         tryAgainDelay: Duration = AppConfig.API.tryAgainDelay,
         onChange: @escaping @MainActor (SportEvent) -> Void) {
        self.event = event
        self.repository = repository
        self.identity = identity
        self.errorCenter = errorCenter
        self.logger = logger
        self.tryAgainDelay = tryAgainDelay
        self.onChange = onChange
    }

    var participation: Participation {
        Participation(event: event, userID: identity.currentUserID)
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
            let updated = try await attemptTwiceOnLostRace(action, change)
            apply(updated)
            logSuccess(action, updated)
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

    /// `TRY_AGAIN` means the request lost a race that is safe to rerun, so one repeat after a short pause spares
    /// the user a second tap. A second `TRY_AGAIN` is treated like any other conflict.
    private func attemptTwiceOnLostRace(_ action: String, _ change: () async throws -> SportEvent) async throws -> SportEvent {
        do {
            return try await change()
        } catch AppError.tryAgain {
            logger.info(.events, "\(action) lost a race for event \(event.id); retrying once")
            try await Task.sleep(for: tryAgainDelay)
            return try await change()
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
        return fresh
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
