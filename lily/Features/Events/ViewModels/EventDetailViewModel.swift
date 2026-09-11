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
    private let onChange: @MainActor (SportEvent) -> Void

    init(event: SportEvent,
         repository: any EventRepository,
         identity: any IdentityProvider,
         errorCenter: ErrorCenter,
         logger: any Logging,
         onChange: @escaping @MainActor (SportEvent) -> Void) {
        self.event = event
        self.repository = repository
        self.identity = identity
        self.errorCenter = errorCenter
        self.logger = logger
        self.onChange = onChange
    }

    var participation: Participation {
        Participation(event: event, userID: identity.currentUserID)
    }

    func join() async {
        await update("Join") { try await repository.join(eventId: event.id) }
    }

    func leave() async {
        await update("Leave") { try await repository.leave(eventId: event.id) }
    }

    /// One change at a time. The server's answer replaces the event and goes to `onChange`, so the list behind this
    /// screen is right on the way back without a reload.
    private func update(_ action: String, _ change: () async throws -> SportEvent) async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            event = try await change()
            onChange(event)
            logger.info(.events, "\(action) succeeded for event \(event.id): \(event.participantCount)/\(event.capacity)")
        } catch {
            guard !AppError.isCancellation(error) else { return }
            logger.error(.events, "\(action) failed for event \(event.id): \(error)")
            errorCenter.report(error)
        }
    }
}
