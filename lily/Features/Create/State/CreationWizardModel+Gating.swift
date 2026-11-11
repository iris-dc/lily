import Foundation

/// The seams the chrome and the pages read (`CreationWizardControlling`): the walk, the per-step gating over
/// `CreationSteps`, the hint copy and the active view model's request state.
extension CreationWizardModel: CreationWizardControlling {
    /// The kind's pages in walking order, derived from the opening alone (its flags, seed and
    /// eligible-groups fact decide the hosting-group pages) so the walk is deterministic per attempt.
    var steps: [CreationStep] { CreationSteps.steps(for: kind, opening: opening) }

    /// The draft on screen, for the shell to watch for edits; the kind's view model is made at init, so this is
    /// its draft (`.none` is only the map's formal fallback).
    var draft: CreationDraft {
        switch kind {
        case .event: eventModel.map { .event($0.draft) } ?? .none
        case .group: groupModel.map { .group($0.draft) } ?? .none
        case .tournament: tournamentModel.map { .tournament($0.draft) } ?? .none
        }
    }

    var isSubmitting: Bool { active?.isSubmitting ?? false }
    var canSubmit: Bool { active?.canSubmit ?? false }
    /// The backend answered; the shell dismisses when it turns true.
    var isDone: Bool { active?.isDone ?? false }

    /// The entered kind's view model behind the shared request-state seam; the drafts stay with the typed accessors.
    var active: (any DraftSubmitting)? {
        switch kind {
        case .event: eventModel
        case .group: groupModel
        case .tournament: tournamentModel
        }
    }

    /// Next may move forward exactly when the step owns none of the live issues.
    func allowsNext(from step: CreationStep) -> Bool {
        switch step {
        case .event(let step): CreationSteps.allowsNext(from: step, issues: eventIssues)
        case .group(let step): CreationSteps.allowsNext(from: step, issues: groupIssues)
        case .tournament(let step): CreationSteps.allowsNext(from: step, issues: tournamentIssues)
        case .eventMap, .groupMap, .tournamentMap: false
        }
    }

    /// The first live issue the step owns, in field order: what the page's hint shows and a refused Next logs.
    func firstBlockingIssue(on step: CreationStep) -> CreationIssue? {
        switch step {
        case .event(let step):
            eventIssues.first { CreationSteps.eventStep(owning: $0) == step }.map(CreationIssue.event)
        case .group(let step):
            groupIssues.first { CreationSteps.groupStep(owning: $0) == step }.map(CreationIssue.group)
        case .tournament(let step):
            tournamentIssues.first { CreationSteps.tournamentStep(owning: $0) == step }.map(CreationIssue.tournament)
        case .eventMap, .groupMap, .tournamentMap:
            nil
        }
    }

    /// The step's first live issue as the copy the hint shows; the mapping stays with each kind's branding (the
    /// tournament's needs the draft's format for the entries limits).
    func blockingMessage(on step: CreationStep) -> String? {
        firstBlockingIssue(on: step).map { issue in
            switch issue {
            case .event(let issue): AppBranding.Events.Create.message(for: issue)
            case .group(let issue): AppBranding.Groups.Create.message(for: issue)
            case .tournament(let issue):
                AppBranding.Tournaments.Create.message(for: issue,
                                                       format: tournamentModel?.draft.format ?? .singleElimination)
            }
        }
    }

    /// The earliest earlier step whose stale issue blocks the final gate; the final page's hint names it.
    func blockedEarlierStep(before step: CreationStep) -> CreationStep? {
        guard let index = steps.firstIndex(of: step) else { return nil }
        return steps.prefix(upTo: index).first { !allowsNext(from: $0) }
    }

    private var eventIssues: [EventDraft.Issue] { eventModel?.issues ?? [] }
    private var groupIssues: [GroupDraft.Issue] { groupModel?.issues ?? [] }
    private var tournamentIssues: [TournamentDraft.Issue] { tournamentModel?.issues ?? [] }
}
