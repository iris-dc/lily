import Foundation

/// What a screen over the group draft needs from its view model, so creating (the wizard's pages) and editing (the
/// form sheet) share one seam. `prepare()` is the parent's: a create proposes the device's position as the spot, an
/// edit has nothing to propose because the group's own place is the draft's already.
protocol GroupDraftEditing: DraftSubmitting where Issue == GroupDraft.Issue {
    var draft: GroupDraft { get set }
    /// Places answering to what is typed into the name field; picking one fills the name and the spot at once.
    func placeSuggestions(for query: String) async -> [PlaceSuggestion]
}

extension GroupDraftEditing {
    /// Only a create offers suggestions (the wizard's place page); the edit form keeps the plain fields.
    func placeSuggestions(for query: String) async -> [PlaceSuggestion] { [] }
}
