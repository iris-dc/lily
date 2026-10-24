import Foundation
import Observation

/// Whether a transcript shows its rows yet. A room opened without its history in the cache lays its first page out
/// with estimated heights that correct themselves over the next frames, each followed by a pin to the bottom; and a
/// page that lands during the push is drawn where UIKit's push animation still takes the scroll view (the offset it
/// had before the page) until the push ends, when it snaps to the pinned one. Hidden instead, the rows are shown once
/// the push has ended and the layout has been quiet for `firstPageRevealQuiet`, or after `firstPageRevealLimit` at the
/// latest, push or not, so nothing keeps them hidden for good. A room the cache held shows at once.
@Observable @MainActor
final class FirstPageReveal {
    private(set) var isShown: Bool
    @ObservationIgnored private var onSettled: (() -> Void)?
    @ObservationIgnored private var quiet: Task<Void, Never>?
    @ObservationIgnored private var limit: Task<Void, Never>?
    /// The screen is not on yet: the push that brings it on still runs, or it left the window.
    @ObservationIgnored private var isArriving = true
    /// The layout went quiet: the push's end shows the rows, if it is still to come.
    @ObservationIgnored private(set) var isSettled = false
    @ObservationIgnored private let sleep: Sleep

    init(isShown: Bool, sleep: @escaping Sleep = systemSleep) {
        self.isShown = isShown
        self.sleep = sleep
    }

    /// A layout pass while hidden: with rows on it (the history's, not only pending ones), `onSettled` (the latest given)
    /// runs once the layout has gone quiet and the screen is on, or at the limit counted from the first such pass.
    func noteLayout(hasRows: Bool, onSettled: @escaping () -> Void) {
        guard !isShown, hasRows else { return }
        self.onSettled = onSettled
        isSettled = false
        quiet?.cancel()
        quiet = settles(after: AppConfig.Chat.firstPageRevealQuiet, isLimit: false)
        if limit == nil { limit = settles(after: AppConfig.Chat.firstPageRevealLimit, isLimit: true) }
    }

    /// The push that brought the screen on has ended; a layout that settled meanwhile shows now.
    func arrived() {
        isArriving = false
        if isSettled, !isShown { onSettled?() }
    }

    /// The screen left the window while hidden (another screen pushed over it): its way back is a transition too.
    func departed() {
        isArriving = true
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

    private func settles(after delay: Duration, isLimit: Bool) -> Task<Void, Never> {
        Task { [sleep] in
            guard (try? await sleep(delay)) != nil, !Task.isCancelled, !isShown else { return }
            isSettled = true
            if isLimit || !isArriving { onSettled?() }
        }
    }
}
