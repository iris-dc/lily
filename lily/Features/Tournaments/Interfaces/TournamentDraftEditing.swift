import Foundation

/// What `TournamentDraftForm` needs from its view model beyond the shared sheet shell, so creating and editing a
/// tournament share one screen.
protocol TournamentDraftEditing: DraftSubmitting where Issue == TournamentDraft.Issue {
    var draft: TournamentDraft { get set }
    /// The earliest start the date picker offers.
    var earliestStart: Date { get }
    /// Where the deadline lands when it is switched on: a day before the start, never before the view model's now.
    func proposedDeadline() -> Date
    /// The entries the stepper offers; an edit's floor is the entries already in.
    var entriesRange: ClosedRange<Int> { get }
    /// After the start the schedule, the draws and the entries are fixed; only the name, description and place change.
    var isLocked: Bool { get }
    /// The type, format, team size and visibility are fixed once the tournament exists: an edit never offers them.
    var allowsStructureChanges: Bool { get }
    /// The group the tournament belongs to when the form may not change it, shown read-only.
    var lockedGroup: EventGroupRef? { get }
    var showsGroupRow: Bool { get }
    var eligibleGroups: [EventGroupRef] { get }
    var explainsNoEligibleGroups: Bool { get }
    /// Whether the eligible-groups read has landed; the wizard's hosting-group page shows a disabled placeholder
    /// until it has.
    var hasLoadedGroups: Bool { get }
    /// Places answering to what is typed into the name field; picking one fills the name and the spot at once.
    func placeSuggestions(for query: String) async -> [PlaceSuggestion]
}

extension TournamentDraftEditing {
    /// Only a create fills these: an edit offers no group choice, since the tournament's group cannot change.
    var eligibleGroups: [EventGroupRef] { [] }

    var explainsNoEligibleGroups: Bool { false }

    /// Only a create reads the groups store; every other flow has nothing pending.
    var hasLoadedGroups: Bool { true }

    /// Only a create offers suggestions (the wizard's place page); the edit form keeps the plain fields.
    func placeSuggestions(for query: String) async -> [PlaceSuggestion] { [] }
}
