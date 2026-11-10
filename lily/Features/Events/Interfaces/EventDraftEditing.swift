import Foundation

/// What `EventDraftForm` needs from its view model beyond the shared sheet shell, so creating and editing a game share
/// one screen.
protocol EventDraftEditing: DraftSubmitting where Issue == EventDraft.Issue {
    var draft: EventDraft { get set }
    /// The earliest start the date picker offers.
    var earliestStart: Date { get }
    /// The capacities the stepper offers; a cap's floor on an edit is the people already in.
    var capacityRange: ClosedRange<Int> { get }
    /// The group the game is hosted in when the form may not change it, shown read-only.
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

extension EventDraftEditing {
    /// An edit offers no group choice: the game's group cannot change, so there is nothing to list and nothing to
    /// explain; only a create fills these.
    var eligibleGroups: [EventGroupRef] { [] }

    var explainsNoEligibleGroups: Bool { false }

    /// Only a create reads the groups store; every other flow has nothing pending.
    var hasLoadedGroups: Bool { true }
}
