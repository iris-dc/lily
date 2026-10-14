import Foundation
import Observation

/// The settings of an existing group as a draft; saved once, then handed to the detail behind the sheet, which
/// writes Mine.
@Observable
final class EditGroupViewModel {
    var draft: GroupDraft
    private(set) var isSubmitting = false
    /// Set once the backend answered; the sheet dismisses when it appears.
    private(set) var updatedGroup: SportGroup?

    private let original: SportGroup
    private let repository: any GroupRepository
    private let logger: any Logging
    private let onChange: @MainActor (SportGroup) -> Void
    private let gate: WriteGate

    init(group: SportGroup,
         repository: any GroupRepository,
         reporter: GroupErrorReporter,
         logger: any Logging,
         tryAgainDelay: Duration = AppConfig.API.tryAgainDelay,
         onChange: @escaping @MainActor (SportGroup) -> Void) {
        self.original = group
        self.draft = GroupDraft(editing: group)
        self.repository = repository
        self.logger = logger
        self.onChange = onChange
        gate = WriteGate(category: .groups, logger: logger, tryAgainDelay: tryAgainDelay, report: { reporter.report($0) })
    }

    var issues: [GroupDraft.Issue] { draft.issues }

    /// Nothing to save until something differs from the group as it is.
    var hasChanges: Bool { draft != GroupDraft(editing: original) }

    var canSubmit: Bool { !isSubmitting && hasChanges && draft.isValid }

    /// Saves the draft; a call while one is in flight is dropped. The gate repeats a `TRY_AGAIN` once, keeps a
    /// dismissed sheet quiet and sends a failure to the popup. Repeating an update is harmless, so there is no outcome
    /// to second-guess.
    func submit() async {
        guard canSubmit else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        await gate.run("Update of group \(original.id)") {
            let group = try await repository.update(id: original.id, draft)
            updatedGroup = group
            onChange(group)
            logger.info(.groups, "Group \(group.id) updated")
        }
    }
}

extension EditGroupViewModel: GroupDraftEditing {
    var isDone: Bool { updatedGroup != nil }
}
