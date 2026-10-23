import SwiftUI

/// The transcript's scrolling: the policy's actions and the debug log a phone's session is read from. A pin scrolls the
/// end marker, a zero-height view after the rows, to the bottom of the visible area, because the scroll view places a
/// view it has laid out exactly: the reported content height carries a lazy stack's estimates of rows it has not
/// measured, and a position bound to the bottom edge rests past the end of those estimates.
extension ChatTranscript {
    /// Judged against the last report the policy saw, not SwiftUI's previous value, which is the last one SwiftUI
    /// computed and may skip changes between two delivered reports. `laidOutRows` is the row count of the body that
    /// made this layout, not the model's: a page the model already holds is not on screen until the next body has run.
    func geometryChanged(to reported: TranscriptScrollPolicy.Snapshot, laidOutRows: Int) {
        var current = reported
        current.isAtBottom = tracker.endIsOnComposer
        let previous = tracker.geometry
        tracker.geometry = current
        let wasSettled = tracker.policy.hasSettled
        let wasFollowing = tracker.policy.isFollowing
        let action = tracker.policy.geometryChanged(from: previous,
                                                    to: current,
                                                    hasRows: laidOutRows > 0,
                                                    canLoadOlder: viewModel.hasOlder && !viewModel.isLoadingOlder,
                                                    oldestID: viewModel.oldestID)
        if !wasSettled, tracker.policy.hasSettled {
            log("settled with \(laidOutRows) rows, \(describe(current))")
        }
        tracker.record(current)
        if tracker.logsThisReport {
            log("report \(action), \(describe(current))")
        } else if action != .none {
            log("\(action) at \(describe(current))")
        }
        if current.bottomInset != previous.bottomInset {
            log("inset \(Int(previous.bottomInset)) to \(Int(current.bottomInset))")
        }
        apply(action)
        if tracker.policy.isFollowing != wasFollowing { logFollowing() }
    }

    func scrollPhaseChanged(from old: ScrollPhase, to new: ScrollPhase) {
        let wasFollowing = tracker.policy.isFollowing
        tracker.geometry.isAtBottom = tracker.endIsOnComposer
        let action = tracker.policy.scrollPhaseChanged(to: TranscriptScrollPolicy.Phase(new), at: tracker.geometry)
        log("scroll \(old) to \(new), \(action), \(describe(tracker.geometry))")
        if tracker.policy.isFollowing != wasFollowing { logFollowing() }
        apply(action)
    }

    private func logFollowing() {
        log(tracker.policy.isFollowing ? "follows the bottom" : "stopped following the bottom")
    }

    func apply(_ action: TranscriptScrollPolicy.Action) {
        switch action {
        case .none:
            break
        case .scrollToBottom:
            position.scrollTo(id: Self.endMarkerID, anchor: .bottom)
        case .animateToBottom:
            // Asked for from the geometry report of the layout that grew the content, where a scroll lands at once; a
            // turn later it is a change of its own and the spring applies.
            Task {
                withAnimation(.messageArrival) { position.scrollTo(id: Self.endMarkerID, anchor: .bottom) }
            }
        case .scrollTo(let y):
            position.scrollTo(y: y)
        case .loadOlder:
            tracker.policy.willLoadOlder(at: tracker.geometry, oldestID: viewModel.oldestID)
            Task { await loadOlderPage() }
        }
    }

    /// The motion of the newest row's arrival, once its spring has settled or the next row cut it short.
    func summarizeArrival(of rowID: String?) async {
        guard let rowID, tracker.motions[rowID] != nil else { return }
        let settling = MessageArrivalCurve.standard.settlingDuration
        let settled = (try? await Task.sleep(for: .seconds(settling))) != nil
        guard let motion = tracker.finishWatching(rowID) else { return }
        log("arrival of row \(rowID) \(settled ? "settled" : "cut short by the next row"): \(motion.summary)")
    }

    func describe(_ snapshot: TranscriptScrollPolicy.Snapshot) -> String {
        let place = snapshot.isAtBottom ? "at the bottom" : "away from the bottom"
        let following = tracker.policy.isFollowing ? "following" : "not following"
        return "height \(Int(snapshot.contentHeight)), offset \(Int(snapshot.offsetY)), inset \(Int(snapshot.bottomInset)), "
            + "end \(Int(tracker.endMarkerY)) of \(Int(tracker.composerLine)), \(place), \(following)"
    }

    func log(_ text: String) {
        viewModel.logger.debug(.chat, "Transcript \(text) in group \(viewModel.group.id)")
    }
}

extension TranscriptScrollPolicy.Phase {
    /// The policy's reading of SwiftUI's phase: the finger on the scroll, a rest, or motion that is not the reader's
    /// hand (a fling running out, an animated scroll, a touch that has not moved yet).
    init(_ phase: ScrollPhase) {
        switch phase {
        case .interacting: self = .touched
        case .idle: self = .resting
        default: self = .moving
        }
    }
}
