import Foundation

/// What a sheet over `GroupDraftForm` needs from its view model, so creating and editing a group share one screen.
/// `prepare()` is the parent's: a create proposes the device's position as the spot, an edit has nothing to propose
/// because the group's own place is the draft's already.
protocol GroupDraftEditing: DraftSubmitting where Issue == GroupDraft.Issue {
    var draft: GroupDraft { get set }
}
