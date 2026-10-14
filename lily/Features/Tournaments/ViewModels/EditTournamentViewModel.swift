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
    private let logger: any Logging
    private let now: () -> Date
    private let onChange: @MainActor (TournamentDetail) -> Void
    private let gate: WriteGate

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
        self.logger = logger
        self.now = now
        self.onChange = onChange
        gate = WriteGate(category: .tournaments, logger: logger, tryAgainDelay: tryAgainDelay, report: { reporter.report($0) })
    }

    var issues: [TournamentDraft.Issue] { draft.issues(now: now(), rules: rules) }
    var hasChanges: Bool { draft != TournamentDraft(editing: original) }
    var canSubmit: Bool { !isSubmitting && hasChanges && issues.isEmpty }
    var isDone: Bool { updated != nil }
    var earliestStart: Date { TournamentDraft.earliestStart(now: now(), rules: rules) }
    func proposedDeadline() -> Date { TournamentDraft.proposedDeadline(before: draft.startsAt, now: now()) }
    var entriesRange: ClosedRange<Int> { rules.entriesRange(for: draft.format) }
    /// After the start the schedule, the draws and the entries are fixed, and the rules stop judging the schedule.
    var isLocked: Bool { !rules.judgesSchedule }
    /// The structure is fixed once the tournament exists.
    var allowsStructureChanges: Bool { false }
    /// The group cannot change; the row shows it read-only, or not at all for a standalone tournament.
    var lockedGroup: EventGroupRef? { original.group }
    var showsGroupRow: Bool { lockedGroup != nil }

    /// Saves the draft through the gate: a `TRY_AGAIN` is repeated once, a dismissed sheet stays quiet, a failure
    /// reaches the popup.
    func submit() async {
        guard canSubmit else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        await gate.run("Update of tournament \(original.id)") {
            let detail = try await repository.update(id: original.id, draft)
            updated = detail
            onChange(detail)
            logger.info(.tournaments, "Tournament \(detail.id) updated (\(detail.tournament.entriesDescription))")
        }
    }
}

extension EditTournamentViewModel: TournamentDraftEditing {}
