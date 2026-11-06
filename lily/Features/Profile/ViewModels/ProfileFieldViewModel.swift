import Foundation
import Observation

/// The two texts of the caller's profile the editors write, each through the store's one write of it.
enum ProfileField {
    case displayName, bio

    func current(in store: ProfileStore) -> String? {
        switch self {
        case .displayName: store.displayName
        case .bio: store.bio
        }
    }

    func write(_ text: String, through store: ProfileStore) async throws -> Profile {
        switch self {
        case .displayName: try await store.rename(to: text)
        case .bio: try await store.updateBio(to: text)
        }
    }

    /// The subject of the error log line; `DisplayNameViewModelTests` pins the name's.
    var logSubject: String {
        switch self {
        case .displayName: "Display name"
        case .bio: "About"
        }
    }
}

/// A profile text editor: one field, Save for a changed valid text, the backend's answer as the new value. A refusal
/// (a blocked word), or a lost answer the store could not settle by reading the profile back, reaches the popup and
/// keeps the draft for a repeat.
@Observable
final class ProfileFieldViewModel<Draft: ProfileFieldDraft>: DraftSubmitting {
    var draft: Draft
    private(set) var isSubmitting = false
    private(set) var isDone = false

    private let field: ProfileField
    private let store: ProfileStore
    private let errorCenter: ErrorCenter
    private let logger: any Logging
    /// The text the field opened with; a draft still equal to it is untouched, so a later answer may refill it.
    private var openingText: String

    init(field: ProfileField, store: ProfileStore, errorCenter: ErrorCenter, logger: any Logging) {
        self.field = field
        self.store = store
        self.errorCenter = errorCenter
        self.logger = logger
        let opening = field.current(in: store) ?? ""
        openingText = opening
        draft = Draft(text: opening)
    }

    var issues: [Draft.Issue] { draft.issues }

    /// Nothing to save until the draft differs from the value the store holds, read when it is judged: the backend's
    /// once the load answered, whether the user typed before or after; nothing while it is unknown, since the write
    /// does not need the read.
    var canSubmit: Bool { !isSubmitting && draft.isValid && draft.trimmedText != (field.current(in: store) ?? "") }

    /// The sheet may open before the profile answered, or after a failed load: the field is filled once the value is
    /// known, unless the user edited it meanwhile (an emptied bio is a choice: it clears).
    func prepare() async {
        await store.loadIfNeeded()
        guard let current = field.current(in: store), draft.text == openingText else { return }
        draft.text = current
        openingText = current
    }

    func submit() async {
        guard canSubmit else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            _ = try await field.write(draft.trimmedText, through: store)
            isDone = true
        } catch {
            guard !AppError.isCancellation(error) else { return }
            logger.error(.auth, "\(field.logSubject) update failed: \(error)")
            errorCenter.report(error)
        }
    }
}

typealias DisplayNameViewModel = ProfileFieldViewModel<DisplayNameDraft>
typealias AboutViewModel = ProfileFieldViewModel<AboutDraft>

extension ProfileFieldViewModel where Draft == DisplayNameDraft {
    convenience init(store: ProfileStore, errorCenter: ErrorCenter, logger: any Logging) {
        self.init(field: .displayName, store: store, errorCenter: errorCenter, logger: logger)
    }
}

extension ProfileFieldViewModel where Draft == AboutDraft {
    convenience init(store: ProfileStore, errorCenter: ErrorCenter, logger: any Logging) {
        self.init(field: .bio, store: store, errorCenter: errorCenter, logger: logger)
    }
}
