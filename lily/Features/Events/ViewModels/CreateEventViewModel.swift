import Foundation
import Observation

/// Owns the draft of a new game and sends it once. The draft judges itself (`EventDraft.issues`); this decides when it
/// may go, keeps a second tap from sending it twice, and hands the created event to the list behind the sheet.
@Observable
final class CreateEventViewModel {
    var draft: EventDraft
    private(set) var isSubmitting = false
    /// Set once the backend answered; the sheet dismisses when it appears.
    private(set) var createdEvent: SportEvent?

    private let repository: any EventRepository
    /// Who is creating; a game found on the backend after a failed create counts as ours only when this user hosts it.
    private let identity: any IdentityProvider
    private let locationService: any LocationService
    private let errorCenter: ErrorCenter
    private let logger: any Logging
    private let now: () -> Date
    private let onCreated: @MainActor (SportEvent) -> Void

    init(repository: any EventRepository,
         identity: any IdentityProvider,
         locationService: any LocationService,
         errorCenter: ErrorCenter,
         logger: any Logging,
         now: @escaping () -> Date = { .now },
         onCreated: @escaping @MainActor (SportEvent) -> Void) {
        self.repository = repository
        self.identity = identity
        self.locationService = locationService
        self.errorCenter = errorCenter
        self.logger = logger
        self.now = now
        self.onCreated = onCreated
        self.draft = EventDraft(startsAt: Self.defaultStart(now: now()))
    }

    /// Everything still wrong with the draft, in field order.
    var issues: [EventDraft.Issue] { draft.issues(now: now()) }

    var canSubmit: Bool { !isSubmitting && issues.isEmpty }

    /// The earliest start the date picker offers.
    var earliestStart: Date { EventDraft.earliestStart(now: now()) }

    /// The first of `candidates` the draft has, for the hint under the field they concern.
    func issue(for candidates: EventDraft.Issue...) -> EventDraft.Issue? {
        let present = issues
        return candidates.first { present.contains($0) }
    }

    /// Proposes the user's position as the spot, so a game "here" needs no map step. A spot already set (the sheet
    /// re-appeared, or the map was quicker) is kept.
    func prepare() async {
        guard draft.coordinate == nil else { return }
        let position = await locationService.currentLocation()
        if draft.coordinate == nil { draft.coordinate = position }
        logger.debug(.location, position == nil ? "No position for the new game; the spot is set on the map"
                                                : "New game proposed at the user's position")
    }

    /// Sends the draft. A call while one is in flight is dropped; a dismissed sheet (cancellation) stays quiet; a
    /// failure goes to the popup, unless the backend turns out to have the game already (see `storedEvent(despite:)`).
    /// The same `clientId` travels with every attempt, so a retry after a lost answer finds the event the backend
    /// already stored instead of creating a second one.
    func submit() async {
        guard canSubmit else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            let event = try await repository.create(draft)
            accept(event)
            logger.info(.events, "Event created \(event.id) (\(event.capacity) spots)")
        } catch {
            guard !AppError.isCancellation(error) else { return }
            logger.error(.events, "Create failed: \(error)")
            if let landed = await storedEvent(despite: error) {
                logger.info(.events, "Create landed for event \(landed.id) despite \(error)")
                accept(landed)
            } else {
                errorCenter.report(error)
            }
        }
    }

    private func accept(_ event: SportEvent) {
        createdEvent = event
        onCreated(event)
    }

    /// A `.network` or `.eventCreationFailed` leaves the outcome unknown: the backend commits before it answers, so
    /// the game may exist although the answer never arrived. It does when the backend has an event under the draft's
    /// id hosted by the caller; anything else (not found, another host's id, a failed lookup) keeps the failure.
    private func storedEvent(despite error: any Error) async -> SportEvent? {
        guard let appError = error as? AppError, appError.leavesCreateOutcomeUnknown else { return nil }
        guard let stored = try? await repository.event(id: draft.clientId) else {
            logger.warning(.events, "Could not check whether the create landed after \(appError)")
            return nil
        }
        guard let hostUserId = stored.hostUserId, hostUserId == identity.currentUserID else { return nil }
        return stored
    }

    /// `AppConfig.Events.Creation.defaultStartOffset` ahead, rounded up to the next full hour: a round time to edit from.
    private static func defaultStart(now: Date) -> Date {
        let target = now.addingTimeInterval(AppConfig.Events.Creation.defaultStartOffset)
        guard let hour = Calendar.current.dateInterval(of: .hour, for: target) else { return target }
        return hour.start == target ? target : hour.end
    }
}

private extension AppError {
    /// Failures after which the create may still have landed (a 500 or a lost connection after the commit): the
    /// create counterpart of the detail screen's `needsRefresh`, without the 409s, which a create never gets.
    var leavesCreateOutcomeUnknown: Bool {
        self == .network || self == .eventCreationFailed
    }
}
