import Foundation

/// An action of the tournament detail waiting for the caller's word, with the words the dialog uses: cancelling,
/// leaving and removing an entry are destructive; starting draws the matches and closes registration for good.
nonisolated enum TournamentConfirmation: Hashable, Identifiable, Sendable {
    case cancel
    case leave
    case start
    case removeEntry(TournamentEntry)

    var id: Self { self }

    private typealias Copy = AppBranding.Tournaments

    func title(name: String) -> String {
        switch self {
        case .cancel: Copy.cancelConfirmation(name: name)
        case .leave: Copy.leaveConfirmation(name: name)
        case .start: Copy.startConfirmationTitle(name: name)
        case .removeEntry(let entry): Copy.removeEntryConfirmation(name: entry.name)
        }
    }

    /// The line under the title; only the start has one, naming the entries that are in ("4 of 8 teams").
    func message(entries: String) -> String? {
        switch self {
        case .start: Copy.startConfirmationMessage(entries: entries)
        case .cancel, .leave, .removeEntry: nil
        }
    }

    var buttonTitle: String {
        switch self {
        case .cancel: Copy.cancel
        case .leave: Copy.leave
        case .start: Copy.start
        case .removeEntry: Copy.removeEntry
        }
    }

    var isDestructive: Bool { self != .start }
}
