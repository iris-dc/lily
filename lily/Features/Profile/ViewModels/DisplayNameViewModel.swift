import Foundation
import Observation

/// The display name editor: one field, Save for a changed valid name, the backend's answer as the new name. A refusal
/// (a blocked word), or a lost answer the store could not settle by reading the profile back, reaches the popup and
/// keeps the draft for a repeat.
@Observable
final class DisplayNameViewModel: DraftSubmitting {
    var draft: DisplayNameDraft
    private(set) var isSubmitting = false
    private(set) var isDone = false

    private let store: ProfileStore
    private let errorCenter: ErrorCenter
    private let logger: any Logging

    init(store: ProfileStore, errorCenter: ErrorCenter, logger: any Logging) {
        self.store = store
        self.errorCenter = errorCenter
        self.logger = logger
        draft = DisplayNameDraft(name: store.displayName ?? "")
    }

    var issues: [DisplayNameDraft.Issue] { draft.issues }

    /// Nothing to save until the draft differs from the name the store holds, read when it is judged: the backend's
    /// once the load answered, whether the user typed before or after; nothing while it is unknown, since the write
    /// does not need the read.
    var canSubmit: Bool { !isSubmitting && draft.isValid && draft.trimmedName != (store.displayName ?? "") }

    /// The sheet may open before the profile answered, or after a failed load: the field is filled once the name is
    /// known, unless the user typed meanwhile.
    func prepare() async {
        await store.loadIfNeeded()
        guard let name = store.displayName, draft.name.isEmpty else { return }
        draft.name = name
    }

    func submit() async {
        guard canSubmit else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            _ = try await store.rename(to: draft.trimmedName)
            isDone = true
        } catch {
            guard !AppError.isCancellation(error) else { return }
            logger.error(.auth, "Display name update failed: \(error)")
            errorCenter.report(error)
        }
    }
}
