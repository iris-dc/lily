import Foundation
import Observation

/// Whether a transcript shows its rows yet. A room opened without its history in the cache lays its first page out
/// with estimated heights that correct themselves over the next frames, each followed by a pin to the bottom; shown at
/// once, the page drew at the wrong place for a frame or more before it settled. Hidden instead, the rows are shown
/// once the layout has been quiet for `firstPageRevealQuiet`, or after `firstPageRevealLimit` at the latest. A room
/// the cache held shows at once.
@Observable @MainActor
final class FirstPageReveal {
    private(set) var isShown: Bool
    @ObservationIgnored private var onSettled: (() -> Void)?
    @ObservationIgnored private var quiet: Task<Void, Never>?
    @ObservationIgnored private var limit: Task<Void, Never>?
    @ObservationIgnored private let sleep: Sleep

    init(isShown: Bool, sleep: @escaping Sleep = systemSleep) {
        self.isShown = isShown
        self.sleep = sleep
    }

    /// A layout pass while hidden: with rows on it (the history's, not only pending ones), `onSettled` (the latest given)
    /// runs once the layout has gone quiet, or at the limit counted from the first such pass.
    func noteLayout(hasRows: Bool, onSettled: @escaping () -> Void) {
        guard !isShown, hasRows else { return }
        self.onSettled = onSettled
        quiet?.cancel()
        quiet = settles(after: AppConfig.Chat.firstPageRevealQuiet)
        if limit == nil { limit = settles(after: AppConfig.Chat.firstPageRevealLimit) }
    }

    /// The history is no longer awaited. Rows wait for their layout to go quiet, as after a layout pass, since the page
    /// may have changed nothing to lay out (rows already pending); with no rows a loaded room has nothing to settle and
    /// shows at once, while a failed one stays hidden, so Try again's page settles out of sight too.
    func historyEnded(hasRows: Bool, loaded: Bool, onSettled: @escaping () -> Void) {
        if hasRows {
            noteLayout(hasRows: true, onSettled: onSettled)
        } else if loaded {
            show()
        }
    }

    /// One spinner until the rows show: while the history is awaited with no rows, then while the rows settle hidden.
    func showsSpinner(hasRows: Bool, isAwaitingHistory: Bool) -> Bool {
        hasRows ? !isShown : isAwaitingHistory
    }

    func show() {
        quiet?.cancel()
        limit?.cancel()
        onSettled = nil
        isShown = true
    }

    private func settles(after delay: Duration) -> Task<Void, Never> {
        Task { [sleep] in
            guard (try? await sleep(delay)) != nil, !Task.isCancelled, !isShown else { return }
            onSettled?()
        }
    }
}
