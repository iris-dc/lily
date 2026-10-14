import Foundation
import Observation

/// Owns the draft of a new tournament and sends it once. The draft judges itself (`TournamentDraft.issues`); this
/// decides when it may go, keeps a second tap from sending it twice, and hands the created tournament on.
@Observable
final class CreateTournamentViewModel {
    var draft: TournamentDraft
    private(set) var isSubmitting = false
    /// Set once the backend answered; the sheet dismisses when it appears.
    private(set) var created: TournamentDetail?
    /// The groups the caller may host a tournament in, read from the store on `prepare()`.
    private(set) var eligibleGroups: [EventGroupRef] = []
    private(set) var belongsToGroups = false
    /// Set when the sheet opened from a group's Tournaments segment: the draft is stamped with it, read-only.
    let lockedGroup: EventGroupRef?

    private let repository: any TournamentRepository
    private let locationService: any LocationService
    private let groups: MyGroupsStore
    private let logger: any Logging
    private let now: () -> Date
    private let pushOptIn: any PushOptIn
    private let onCreated: @MainActor (TournamentDetail) -> Void
    private let flow: CreateFlow<TournamentDetail>

    init(repository: any TournamentRepository,
         identity: any IdentityProvider,
         locationService: any LocationService,
         groups: MyGroupsStore,
         reporter: GroupErrorReporter,
         logger: any Logging,
         now: @escaping () -> Date = { .now },
         calendar: Calendar = .current,
         pushOptIn: any PushOptIn = NoPushOptIn(),
         lockedGroup: EventGroupRef? = nil,
         onCreated: @escaping @MainActor (TournamentDetail) -> Void) {
        self.repository = repository
        self.locationService = locationService
        self.groups = groups
        self.logger = logger
        self.now = now
        self.pushOptIn = pushOptIn
        self.lockedGroup = lockedGroup
        self.onCreated = onCreated
        flow = CreateFlow(noun: "tournament",
                          category: .tournaments,
                          logger: logger,
                          report: { reporter.report($0) },
                          leavesOutcomeUnknown: { $0 == .network || $0 == .tournamentCreationFailed },
                          notFound: .tournamentNotFound,
                          lookup: { try await repository.tournament(id: $0) },
                          isOurs: { $0.tournament.isOrganized(by: identity.currentUserID) })
        self.draft = TournamentDraft(startsAt: Self.defaultStart(now: now(), calendar: calendar))
        self.draft.group = lockedGroup
    }

    var issues: [TournamentDraft.Issue] { draft.issues(now: now()) }
    var canSubmit: Bool { !isSubmitting && issues.isEmpty }
    var isDone: Bool { created != nil }
    var earliestStart: Date { TournamentDraft.earliestStart(now: now()) }
    func proposedDeadline() -> Date { TournamentDraft.proposedDeadline(before: draft.startsAt, now: now()) }
    var entriesRange: ClosedRange<Int> { TournamentDraft.Rules.creation.entriesRange(for: draft.format) }
    /// A new tournament's format, team size and visibility are the organiser's to choose.
    var isLocked: Bool { false }
    var allowsStructureChanges: Bool { true }
    var showsGroupRow: Bool { lockedGroup != nil || belongsToGroups }
    var explainsNoEligibleGroups: Bool { lockedGroup == nil && belongsToGroups && eligibleGroups.isEmpty }

    /// Reads the groups the caller may host in (no request) and proposes the user's position as the place.
    func prepare() async {
        eligibleGroups = groups.eligibleForEvents.map(\.ref)
        belongsToGroups = !groups.communities.isEmpty
        guard draft.coordinate == nil else { return }
        let position = await locationService.currentLocation()
        if draft.coordinate == nil { draft.coordinate = position }
        logger.debug(.location, position == nil ? "No position for the new tournament; the spot is set on the map"
                                                : "New tournament proposed at the user's position")
    }

    /// Sends the draft. A call while one is in flight is dropped; a dismissed sheet stays quiet; a failure goes to the
    /// popup unless the backend turns out to have the tournament already (`CreateFlow`: the same `clientId` travels
    /// with every attempt, so the lookup after a lost answer finds what the backend stored).
    func submit() async {
        guard canSubmit else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        let created = await flow.submit(clientID: draft.clientId,
                                        describing: { "(\($0.tournament.entriesDescription))\(groupSuffix($0))" },
                                        send: { try await repository.create(draft) })
        if let created { await accept(created) }
    }

    private func accept(_ detail: TournamentDetail) async {
        created = detail
        onCreated(detail)
        await pushOptIn.offerReminders()
    }

    private func groupSuffix(_ detail: TournamentDetail) -> String {
        detail.tournament.group.map { " in group \($0.id)" } ?? ""
    }

    /// `AppConfig.Tournaments.defaultStartOffset` ahead, rounded up to the next full hour.
    private static func defaultStart(now: Date, calendar: Calendar) -> Date {
        calendar.nextFullHour(after: now.addingTimeInterval(AppConfig.Tournaments.defaultStartOffset))
    }
}

extension CreateTournamentViewModel: TournamentDraftEditing {}
