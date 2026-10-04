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
    private let identity: any IdentityProvider
    private let locationService: any LocationService
    private let groups: MyGroupsStore
    private let reporter: GroupErrorReporter
    private let logger: any Logging
    private let now: () -> Date
    private let pushOptIn: any PushOptIn
    private let onCreated: @MainActor (TournamentDetail) -> Void

    init(repository: any TournamentRepository,
         identity: any IdentityProvider,
         locationService: any LocationService,
         groups: MyGroupsStore,
         reporter: GroupErrorReporter,
         logger: any Logging,
         now: @escaping () -> Date = { .now },
         pushOptIn: any PushOptIn = NoPushOptIn(),
         lockedGroup: EventGroupRef? = nil,
         onCreated: @escaping @MainActor (TournamentDetail) -> Void) {
        self.repository = repository
        self.identity = identity
        self.locationService = locationService
        self.groups = groups
        self.reporter = reporter
        self.logger = logger
        self.now = now
        self.pushOptIn = pushOptIn
        self.lockedGroup = lockedGroup
        self.onCreated = onCreated
        self.draft = TournamentDraft(startsAt: Self.defaultStart(now: now()))
        self.draft.group = lockedGroup
    }

    var issues: [TournamentDraft.Issue] { draft.issues(now: now()) }
    var canSubmit: Bool { !isSubmitting && issues.isEmpty }
    var isDone: Bool { created != nil }
    var earliestStart: Date { TournamentDraft.earliestStart(now: now()) }
    var entriesRange: ClosedRange<Int> { TournamentDraft.Rules.creation.entriesRange(for: draft.format) }
    /// A new tournament's format, team size and visibility are the organiser's to choose.
    var isLocked: Bool { false }
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
    /// popup unless the backend turns out to have the tournament already (`stored(despite:)`).
    func submit() async {
        guard canSubmit else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            let detail = try await repository.create(draft)
            await accept(detail)
            let shape = detail.tournament.entriesDescription
            logger.info(.tournaments, "Tournament created \(detail.id) (\(shape))\(groupSuffix(detail))")
        } catch {
            guard !AppError.isCancellation(error) else { return }
            logger.error(.tournaments, "Create failed: \(error)")
            if let landed = await stored(despite: error) {
                logger.info(.tournaments, "Create landed for tournament \(landed.id) despite \(error)")
                await accept(landed)
            } else {
                reporter.report(error)
            }
        }
    }

    private func accept(_ detail: TournamentDetail) async {
        created = detail
        onCreated(detail)
        await pushOptIn.offerReminders()
    }

    /// A `.network` or `.tournamentCreationFailed` leaves the outcome unknown: the backend commits before it answers.
    /// The tournament is ours when it exists under the draft's id and the caller organises it.
    private func stored(despite error: any Error) async -> TournamentDetail? {
        guard let appError = error as? AppError, appError == .network || appError == .tournamentCreationFailed else { return nil }
        guard let stored = try? await repository.tournament(id: draft.clientId) else {
            logger.warning(.tournaments, "Could not check whether the create landed after \(appError)")
            return nil
        }
        return stored.tournament.isOrganized(by: identity.currentUserID) ? stored : nil
    }

    private func groupSuffix(_ detail: TournamentDetail) -> String {
        detail.tournament.group.map { " in group \($0.id)" } ?? ""
    }

    /// `AppConfig.Tournaments.defaultStartOffset` ahead, rounded up to the next full hour.
    private static func defaultStart(now: Date) -> Date {
        let target = now.addingTimeInterval(AppConfig.Tournaments.defaultStartOffset)
        guard let hour = Calendar.current.dateInterval(of: .hour, for: target) else { return target }
        return hour.start == target ? target : hour.end
    }
}
