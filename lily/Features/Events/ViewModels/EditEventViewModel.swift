import Foundation
import Observation

/// The host's own game as a draft; saved once, then handed to the detail behind the sheet. Judged by the editing rules:
/// the start only needs to lie ahead, and the spots never drop below the people already in.
@Observable
final class EditEventViewModel {
    var draft: EventDraft
    private(set) var isSubmitting = false
    /// Set once the backend answered; the sheet dismisses when it appears.
    private(set) var updatedEvent: SportEvent?

    private let original: SportEvent
    private let rules: EventDraft.Rules
    /// The user's currency, for a price added to a game that had none; a priced game keeps its own.
    private let currencyCode: String
    private let repository: any EventRepository
    private let errorCenter: ErrorCenter
    private let logger: any Logging
    private let tryAgainDelay: Duration
    private let now: () -> Date
    private let onChange: @MainActor (SportEvent) -> Void

    init(event: SportEvent,
         repository: any EventRepository,
         errorCenter: ErrorCenter,
         logger: any Logging,
         tryAgainDelay: Duration = AppConfig.API.tryAgainDelay,
         now: @escaping () -> Date = { .now },
         currencyCode: String,
         onChange: @escaping @MainActor (SportEvent) -> Void) {
        self.original = event
        self.currencyCode = currencyCode
        self.draft = EventDraft(editing: event, currencyCode: currencyCode)
        self.rules = .editing(participantCount: event.participantCount)
        self.repository = repository
        self.errorCenter = errorCenter
        self.logger = logger
        self.tryAgainDelay = tryAgainDelay
        self.now = now
        self.onChange = onChange
    }

    var issues: [EventDraft.Issue] { draft.issues(now: now(), rules: rules) }

    /// Nothing to save until something differs from the game as it is.
    var hasChanges: Bool { draft != EventDraft(editing: original, currencyCode: currencyCode) }

    var canSubmit: Bool { !isSubmitting && hasChanges && issues.isEmpty }

    var isDone: Bool { updatedEvent != nil }

    var earliestStart: Date { EventDraft.earliestStart(now: now(), rules: rules) }

    var capacityRange: ClosedRange<Int> { rules.capacityRange(for: draft.playerLimit) }

    /// The group a game is hosted in cannot change, so the row shows it read-only, or not at all for a game of its own.
    var lockedGroup: EventGroupRef? { original.group }

    var showsGroupRow: Bool { lockedGroup != nil }

    var eligibleGroups: [EventGroupRef] { [] }

    var explainsNoEligibleGroups: Bool { false }

    /// The draft is the event already; nothing to fetch before the form shows.
    func prepare() async {}

    /// Saves the draft; a call while one is in flight is dropped, a dismissed sheet stays quiet, a failure goes to
    /// the popup. A `TRY_AGAIN` (the backend pins the start it read, so another edit landing meanwhile refuses this
    /// one) is repeated once, like a join. Repeating an update is harmless, so there is no outcome to second-guess.
    func submit() async {
        guard canSubmit else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            let event = try await LostRace.attemptTwice(delay: tryAgainDelay, onRetry: logRetry) {
                try await repository.update(id: original.id, draft)
            }
            updatedEvent = event
            onChange(event)
            logger.info(.events, "Event \(event.id) updated (\(event.spotsDescription))")
        } catch {
            guard !AppError.isCancellation(error) else { return }
            logger.error(.events, "Update failed for event \(original.id): \(error)")
            errorCenter.report(error)
        }
    }

    private func logRetry() {
        logger.info(.events, "Update lost a race for event \(original.id); retrying once")
    }
}
