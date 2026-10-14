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
    /// The groups the caller may host a game in, read from the store on `prepare()`; the form's picker offers them.
    private(set) var eligibleGroups: [EventGroupRef] = []
    /// Whether the caller belongs to any group at all; with groups but none eligible, the row explains why.
    private(set) var belongsToGroups = false
    /// Set when the sheet opened from a group's Events segment: the draft is stamped with it and the form shows it
    /// read-only instead of the picker.
    let lockedGroup: EventGroupRef?

    private let repository: any EventRepository
    private let locationService: any LocationService
    private let groups: MyGroupsStore
    private let logger: any Logging
    /// A `.network` or `.eventCreationFailed` leaves the outcome unknown; the game is ours when the caller hosts what
    /// the backend holds under the draft's id (another host's, the backend's `EVENT_ID_TAKEN`, keeps the failure).
    private let flow: CreateFlow<SportEvent>
    private let now: () -> Date
    /// Asked after a successful create: the host wants the reminder too.
    private let pushOptIn: any PushOptIn
    private let onCreated: @MainActor (SportEvent) -> Void

    init(repository: any EventRepository,
         identity: any IdentityProvider,
         locationService: any LocationService,
         groups: MyGroupsStore,
         errorCenter: ErrorCenter,
         logger: any Logging,
         now: @escaping () -> Date = { .now },
         calendar: Calendar = .current,
         currencyCode: String,
         pushOptIn: any PushOptIn = NoPushOptIn(),
         lockedGroup: EventGroupRef? = nil,
         onCreated: @escaping @MainActor (SportEvent) -> Void) {
        self.repository = repository
        self.locationService = locationService
        self.groups = groups
        self.logger = logger
        self.now = now
        self.pushOptIn = pushOptIn
        self.lockedGroup = lockedGroup
        self.onCreated = onCreated
        flow = CreateFlow(noun: "event",
                          category: .events,
                          logger: logger,
                          report: { errorCenter.report($0) },
                          leavesOutcomeUnknown: { $0.leavesCreateOutcomeUnknown },
                          notFound: .eventNotFound,
                          lookup: { try await repository.event(id: $0) },
                          isOurs: { $0.hostUserId != nil && $0.hostUserId == identity.currentUserID })
        self.draft = EventDraft(startsAt: Self.defaultStart(now: now(), calendar: calendar), currencyCode: currencyCode)
        self.draft.group = lockedGroup
    }

    /// Everything still wrong with the draft, in field order.
    var issues: [EventDraft.Issue] { draft.issues(now: now()) }

    var canSubmit: Bool { !isSubmitting && issues.isEmpty }

    var isDone: Bool { createdEvent != nil }

    /// The earliest start the date picker offers.
    var earliestStart: Date { EventDraft.earliestStart(now: now()) }

    var capacityRange: ClosedRange<Int> { EventDraft.Rules.creation.capacityRange(for: draft.playerLimit) }

    /// The row shows for a preset group and for anyone in a group, so a member who may not host still sees why.
    var showsGroupRow: Bool { lockedGroup != nil || belongsToGroups }

    /// The caller is in groups, but none lets them host: the row is read-only and the footer says so.
    var explainsNoEligibleGroups: Bool { lockedGroup == nil && belongsToGroups && eligibleGroups.isEmpty }

    /// Reads the groups the caller may host in (no request: the store is loaded on sign-in) and proposes the user's
    /// position as the spot, so a game "here" needs no map step. A spot already set (the sheet re-appeared, or the
    /// map was quicker) is kept.
    func prepare() async {
        eligibleGroups = groups.eligibleForEvents.map(\.ref)
        belongsToGroups = !groups.communities.isEmpty
        guard draft.coordinate == nil else { return }
        let position = await locationService.currentLocation()
        if draft.coordinate == nil { draft.coordinate = position }
        logger.debug(.location, position == nil ? "No position for the new game; the spot is set on the map"
                                                : "New game proposed at the user's position")
    }

    /// Sends the draft. A call while one is in flight is dropped; a dismissed sheet (cancellation) stays quiet; a
    /// failure goes to the popup, unless the backend turns out to have the game already (`CreateFlow`). The same
    /// `clientId` travels with every attempt, so a retry after a lost answer finds the event the backend already
    /// stored instead of creating a second one.
    func submit() async {
        guard canSubmit else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        let created = await flow.submit(clientID: draft.clientId,
                                        describing: { "(\($0.spotsDescription))\(Self.groupSuffix(for: $0))" },
                                        send: { try await repository.create(draft) })
        if let created { await accept(created) }
    }

    /// The sheet dismisses on `createdEvent`; the permission prompt, when it is due, comes up over the screen behind.
    private func accept(_ event: SportEvent) async {
        createdEvent = event
        onCreated(event)
        await pushOptIn.offerReminders()
    }

    /// The group id for the log line; ids only, never the name.
    private static func groupSuffix(for event: SportEvent) -> String {
        event.group.map { " in group \($0.id)" } ?? ""
    }

    /// `AppConfig.Events.Creation.defaultStartOffset` ahead, rounded up to the next full hour: a round time to edit from.
    private static func defaultStart(now: Date, calendar: Calendar) -> Date {
        calendar.nextFullHour(after: now.addingTimeInterval(AppConfig.Events.Creation.defaultStartOffset))
    }
}

private extension AppError {
    /// Failures after which the create may still have landed (a 500 or a lost connection after the commit): the
    /// create counterpart of the detail screen's `needsRefresh`, without the 409s, which a create never gets.
    var leavesCreateOutcomeUnknown: Bool {
        self == .network || self == .eventCreationFailed
    }
}

extension CreateEventViewModel: EventDraftEditing {}
