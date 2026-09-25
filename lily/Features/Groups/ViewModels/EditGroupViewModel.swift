import Foundation
import Observation

/// The settings of an existing group as a draft; saved once, then handed to Mine and the detail behind the sheet.
@Observable
final class EditGroupViewModel {
    var draft: GroupDraft
    private(set) var isSubmitting = false
    /// Set once the backend answered; the sheet dismisses when it appears.
    private(set) var updatedGroup: SportGroup?

    private let original: SportGroup
    private let repository: any GroupRepository
    private let store: MyGroupsStore
    private let reporter: GroupErrorReporter
    private let logger: any Logging
    private let onChange: @MainActor (SportGroup) -> Void

    init(group: SportGroup,
         repository: any GroupRepository,
         store: MyGroupsStore,
         reporter: GroupErrorReporter,
         logger: any Logging,
         onChange: @escaping @MainActor (SportGroup) -> Void) {
        self.original = group
        self.draft = GroupDraft(editing: group)
        self.repository = repository
        self.store = store
        self.reporter = reporter
        self.logger = logger
        self.onChange = onChange
    }

    var issues: [GroupDraft.Issue] { draft.issues }

    /// Nothing to save until something differs from the group as it is.
    var hasChanges: Bool { draft != GroupDraft(editing: original) }

    var canSubmit: Bool { !isSubmitting && hasChanges && draft.isValid }

    func issue(for candidates: GroupDraft.Issue...) -> GroupDraft.Issue? {
        let present = issues
        return candidates.first { present.contains($0) }
    }

    /// Saves the draft; a call while one is in flight is dropped, a dismissed sheet stays quiet, a failure goes to
    /// the popup. Repeating an update is harmless, so there is no outcome to second-guess.
    func submit() async {
        guard canSubmit else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            let group = try await repository.update(id: original.id, draft)
            updatedGroup = group
            store.replace(group)
            onChange(group)
            logger.info(.groups, "Group \(group.id) updated")
        } catch {
            guard !AppError.isCancellation(error) else { return }
            logger.error(.groups, "Update failed for group \(original.id): \(error)")
            reporter.report(error)
        }
    }
}
