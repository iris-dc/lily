import Foundation
import Observation

/// The organiser's own tournament as a draft; saved once, then handed to the detail behind the sheet. Judged by the
/// editing rules: the start only needs to lie ahead, the entries never drop below those already in, and after the
/// start only the name, the description and the place may change (`isLocked`).
@Observable
final class EditTournamentViewModel {
    var draft: TournamentDraft
    private(set) var isSubmitting = false
    private(set) var updated: TournamentDetail?

    private let original: Tournament
    private let rules: TournamentDraft.Rules
    private let repository: any TournamentRepository
    private let reporter: GroupErrorReporter
    private let logger: any Logging
    private let tryAgainDelay: Duration
    private let now: () -> Date
    private let onChange: @MainActor (TournamentDetail) -> Void

    init(tournament: Tournament,
         repository: any TournamentRepository,
         reporter: GroupErrorReporter,
         logger: any Logging,
         tryAgainDelay: Duration = AppConfig.API.tryAgainDelay,
         now: @escaping () -> Date = { .now },
         onChange: @escaping @MainActor (TournamentDetail) -> Void) {
        self.original = tournament
        self.draft = TournamentDraft(editing: tournament)
        self.rules = .editing(entryCount: tournament.entryCount, isLocked: tournament.status != .registration)
        self.repository = repository
        self.reporter = reporter
        self.logger = logger
        self.tryAgainDelay = tryAgainDelay
        self.now = now
        self.onChange = onChange
    }

    var issues: [TournamentDraft.Issue] { draft.issues(now: now(), rules: rules) }
    var hasChanges: Bool { draft != TournamentDraft(editing: original) }
    var canSubmit: Bool { !isSubmitting && hasChanges && issues.isEmpty }
    var isDone: Bool { updated != nil }
    var earliestStart: Date { TournamentDraft.earliestStart(now: now(), rules: rules) }
    var entriesRange: ClosedRange<Int> { rules.entriesRange(for: draft.format) }
    /// After the start the schedule, the draws and the entries are fixed, and the rules stop judging the schedule.
    var isLocked: Bool { !rules.judgesSchedule }
    /// The group cannot change; the row shows it read-only, or not at all for a standalone tournament.
    var lockedGroup: EventGroupRef? { original.group }
    var showsGroupRow: Bool { lockedGroup != nil }
    var eligibleGroups: [EventGroupRef] { [] }
    var explainsNoEligibleGroups: Bool { false }

    /// The draft is the tournament already; nothing to fetch before the form shows.
    func prepare() async {}

    /// Saves the draft; a `TRY_AGAIN` is repeated once; a failure goes to the popup.
    func submit() async {
        guard canSubmit else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            let detail = try await LostRace.attemptTwice(delay: tryAgainDelay, onRetry: logRetry) {
                try await repository.update(id: original.id, draft)
            }
            updated = detail
            onChange(detail)
            logger.info(.tournaments, "Tournament \(detail.id) updated (\(detail.tournament.entriesDescription))")
        } catch {
            guard !AppError.isCancellation(error) else { return }
            logger.error(.tournaments, "Update failed for tournament \(original.id): \(error)")
            reporter.report(error)
        }
    }

    private func logRetry() {
        logger.info(.tournaments, "Update lost a race for tournament \(original.id); retrying once")
    }
}
