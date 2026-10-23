import SwiftUI

/// The viewer's moves: the way in out of the tile, the drag, the way back to the middle and the way out onto the tile,
/// each started and finished through `ViewerMotion`.
extension AttachmentViewerSheet {
    /// The way in, back and out, over an exact time, each handing over to the pager or the chat once removed, the
    /// moment it ends.
    var transition: Animation {
        .timingCurve(DesignTokens.Duration.viewerTransitionCurve, duration: DesignTokens.Duration.viewerTransition)
    }

    /// Out of the tile: the first frame draws the picture on it, then it grows to fill the screen, a turn later, once
    /// the page has laid out where it will end.
    func open() {
        hero.shownID = current.id
        hero.log("opens \(current.id) from tile \(ViewerHero.describe(hero.tiles[current.id]?.frame)), page "
                 + ViewerHero.describe(layout.frames[current.id]))
        let move = motion.startOpening()
        Task { @MainActor in
            hero.log("grows \(current.id) to page \(ViewerHero.describe(layout.frames[current.id]))")
            withAnimation(transition, completionCriteria: .removed) {
                progress = 0
            } completion: {
                _ = motion.finish(move)
            }
        }
    }

    func dragged(_ translation: CGSize) {
        guard motion.drag() else { return }
        drag = translation.height
    }

    /// Far or fast enough closes; short of it the picture goes back to the middle.
    func letGo(at translation: CGSize, velocity: CGSize, wasCancelled: Bool) {
        if !wasCancelled, ViewerDismissal.closes(drag: translation.height, velocity: velocity.height) {
            close()
        } else {
            settle()
        }
    }

    func settle() {
        guard let move = motion.startSettling() else { return }
        withAnimation(transition, completionCriteria: .removed) {
            drag = 0
        } completion: {
            _ = motion.finish(move)
        }
    }

    /// Back onto the tile of the page on screen.
    func close() {
        guard let move = motion.startClosing() else { return }
        landing = tile?.frame
        hero.log("closes \(current.id) onto tile \(ViewerHero.describe(landing)), dragged \(Int(drag))")
        withAnimation(transition, completionCriteria: .removed) {
            progress = 1
            drag = 0
        } completion: {
            guard motion.finish(move) else { return }
            followTileThenLeave()
        }
    }

    /// The chat moved under the closing picture (a line arrived, the keyboard went): the picture catches its tile up
    /// before the chat takes over, rather than the tile jumping into place after.
    private func followTileThenLeave() {
        guard let landing, let now = hero.tiles[current.id]?.frame,
              abs(now.minX - landing.minX) + abs(now.minY - landing.minY) > 1 else {
            handOver()
            return
        }
        hero.log("tile of \(current.id) moved while closing to \(ViewerHero.describe(now)); following")
        withAnimation(.easeOut(duration: DesignTokens.Duration.fast), completionCriteria: .removed) {
            self.landing = now
        } completion: {
            handOver()
        }
    }

    /// On its tile: the tile shows its picture again under this one, and the cover goes on the next turn, so no frame
    /// shows the accent or an empty tile.
    private func handOver() {
        hero.log("closed \(current.id); tile at \(ViewerHero.describe(hero.tiles[current.id]?.frame))")
        hero.shownID = nil
        hero.forgetPreloaded()
        Task { @MainActor in leave() }
    }

    /// Takes the cover away without its slide: the viewer has already drawn its going.
    private func leave() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { dismiss() }
    }
}
