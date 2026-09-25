import Foundation
import Observation

/// Owns the draft of a new group and sends it once. The draft judges itself (`GroupDraft.issues`); this decides when
/// it may go, keeps a second tap from sending it twice, and hands the created group to Mine and the sheet's caller.
@Observable
final class CreateGroupViewModel {
    var draft = GroupDraft()
    private(set) var isSubmitting = false
    /// Set once the backend answered; the sheet dismisses when it appears.
    private(set) var createdGroup: SportGroup?

    private let repository: any GroupRepository
    private let store: MyGroupsStore
    private let reporter: GroupErrorReporter
    private let logger: any Logging
    private let onCreated: @MainActor (SportGroup) -> Void

    init(repository: any GroupRepository,
         store: MyGroupsStore,
         reporter: GroupErrorReporter,
         logger: any Logging,
         onCreated: @escaping @MainActor (SportGroup) -> Void) {
        self.repository = repository
        self.store = store
        self.reporter = reporter
        self.logger = logger
        self.onCreated = onCreated
    }

    var issues: [GroupDraft.Issue] { draft.issues }

    var canSubmit: Bool { !isSubmitting && draft.isValid }

    /// The first of `candidates` the draft has, for the hint under the field they concern.
    func issue(for candidates: GroupDraft.Issue...) -> GroupDraft.Issue? {
        let present = issues
        return candidates.first { present.contains($0) }
    }

    /// Sends the draft. A call while one is in flight is dropped; a dismissed sheet (cancellation) stays quiet; a
    /// failure goes to the popup unless the backend turns out to have the group already. The same `clientId` travels
    /// with every attempt, so a retry after a lost answer finds the group instead of creating a second one.
    func submit() async {
        guard canSubmit else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            let group = try await repository.create(draft)
            accept(group)
            logger.info(.groups, "Group created \(group.id) (\(group.visibility.rawValue))")
        } catch {
            guard !AppError.isCancellation(error) else { return }
            logger.error(.groups, "Create failed: \(error)")
            if let landed = await storedGroup(despite: error) {
                logger.info(.groups, "Create landed for group \(landed.id) despite \(error)")
                accept(landed)
            } else {
                reporter.report(error)
            }
        }
    }

    private func accept(_ group: SportGroup) {
        createdGroup = group
        store.add(group)
        onCreated(group)
    }

    /// A `.network` or `.groupCreationFailed` (which also covers an id another user owns) leaves the outcome unknown:
    /// the backend commits before it answers. The group is ours when it exists under the draft's id and the caller
    /// owns it; anything else keeps the failure.
    private func storedGroup(despite error: any Error) async -> SportGroup? {
        guard let appError = error as? AppError, appError == .network || appError == .groupCreationFailed else { return nil }
        do {
            let stored = try await repository.group(id: draft.clientId)
            return stored.role == .owner ? stored : nil
        } catch {
            if !AppError.isCancellation(error) {
                logger.warning(.groups, "Could not check whether the create landed after \(appError)")
            }
            return nil
        }
    }
}
