import Foundation

/// One kind's validation issue under the wizard's roof, for the seams that serve every kind (the step hints, the
/// refused-Next debug line); the per-kind partitions stay typed in `CreationSteps`.
nonisolated enum CreationIssue: Hashable, Sendable {
    case event(EventDraft.Issue)
    case group(GroupDraft.Issue)
    case tournament(TournamentDraft.Issue)

    /// The wrapped case's kind-prefixed name for the refused-Next debug line ("group.nameTooShort"); issue ids
    /// only, never user text.
    var logName: String {
        switch self {
        case .event(let issue): "event.\(String(describing: issue))"
        case .group(let issue): "group.\(String(describing: issue))"
        case .tournament(let issue): "tournament.\(String(describing: issue))"
        }
    }
}
