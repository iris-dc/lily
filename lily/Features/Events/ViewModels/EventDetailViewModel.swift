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
    /// Asked after a successful join: the reminder it buys is for this very game.
    private let pushOptIn: any PushOptIn
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
         pushOptIn: any PushOptIn = NoPushOptIn(),
         onChange: @escaping @MainActor (SportEvent) -> Void) {
        self.event = event
        self.pushOptIn = pushOptIn
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

    /// The host's profile, when the caller may open it: signed in, the host known, not the caller themselves, and the
    /// host's account not deleted (a tombstone opens no profile).
    var hostProfile: UserProfileDestination? {
        guard let hostUserId = event.hostUserId, let caller = identity.currentUserID, hostUserId != caller,
              event.deleted != true else { return nil }
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

    /// A join that landed, directly or by the read-back, earns the reminder prompt once the control is free: the
    /// offer runs after `update` released `isBusy`, so a Leave tapped during the prompt owns the flag to its own end.
    func join() async {
        guard await update("Join", wantsToParticipate: true, { try await repository.join(eventId: event.id) }) else { return }
        await pushOptIn.offerReminders()
    }

    func leave() async {
        await update("Leave", wantsToParticipate: false) { try await repository.leave(eventId: event.id) }
    }

    /// One change at a time, through the shared gate (`WriteGate`: one `TRY_AGAIN` repeated, a cancellation quiet, a
    /// refusal logged at warning). The server's answer replaces the event and goes to `onChange`, so the list behind
    /// this screen is right on the way back without a reload. A refusal because the event moved on is shown, but only
    /// after the event on screen has been read back, so the popup and the numbers agree; a failure that leaves the
    /// outcome unknown is shown only when the read-back does not already show what the user asked for (`LostAnswer`):
    /// Laurel commits a join before it reads the event back, so the write may have landed, and a popup saying otherwise
    /// would only send the user into an "already joined" refusal. Answers whether the change landed; `isBusy` is held
    /// exactly as long as the write is settling.
    @discardableResult
    private func update(_ action: String, wantsToParticipate: Bool, _ change: () async throws -> SportEvent) async -> Bool {
        guard !isBusy else { return false }
        isBusy = true
        defer { isBusy = false }
        let what = "\(action) for event \(event.id)"
        return await gate.run(what,
                              settling: { [self] error in
                                  await readBack(what, despite: error, wantsToParticipate: wantsToParticipate)
                              },
                              { [self] in
                                  let updated = try await change()
                                  apply(updated)
                                  logSuccess(action, updated)
                                  await loadParticipants()
                              })
    }

    private func logSuccess(_ action: String, _ updated: SportEvent) {
        logger.info(.events, "\(action) succeeded for event \(updated.id): \(updated.countDescription)")
        if updated.isFull { logger.info(.events, "Capacity reached for event \(updated.id)") }
    }

    /// Reads the event back and answers whether the write landed; the roster follows every fresh event.
    private func readBack(_ what: String, despite error: any Error, wantsToParticipate: Bool) async -> Bool {
        let settlement = await eventReadBack.settle(what, despite: error) { $0.participates == wantsToParticipate }
        if settlement != .unresolved { await loadParticipants() }
        return settlement.isLanded
    }

    private var gate: WriteGate {
        WriteGate(category: .events,
                  logger: logger,
                  tryAgainDelay: tryAgainDelay,
                  report: { [errorCenter] in errorCenter.report($0) },
                  isExpected: { $0.isParticipationConflict })
    }

    /// The event is read back after every refusal (the screen was stale; the popup still explains it) and after a 500
    /// or a lost connection (`participationFailed` is the participation routes' fallback), when a fresh event already
    /// showing the change means the write landed.
    private var eventReadBack: LostAnswer<SportEvent> {
        LostAnswer(category: .events,
                   logger: logger,
                   leavesOutcomeUnknown: { $0 == .participationFailed || $0 == .network },
                   isWorthAnotherLook: { $0.isParticipationConflict },
                   refetch: { [self] in try await repository.event(id: event.id) },
                   apply: { [self] in apply($0) })
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
}
