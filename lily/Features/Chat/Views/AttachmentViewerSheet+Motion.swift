import SwiftUI

/// The viewer's moves: the way in out of the tile, the drag, the way back to the middle and the way out onto the tile,
/// each started and finished through `ViewerMotion` and run frame by frame by the `ViewerMoveDriver`, which writes the
/// shared state both halves of the picture draw from.
extension AttachmentViewerSheet {
    /// The way in, back and out take an exact time, each handing over to the pager or the chat the moment it ends; a
    /// move out of a drag starts at speed, one from rest gently.
    func curve(fromDrag: Bool) -> UnitCurve {
        fromDrag ? DesignTokens.Duration.viewerThrowCurve : DesignTokens.Duration.viewerTransitionCurve
    }

    /// Out of the tile: the first frame draws the picture on it, then it grows to fill the screen, a turn later, once
    /// the page has laid out where it will end.
    func open() {
        hero.shownID = current.id
        stage()
        hero.log("opens \(current.id) from tile \(ViewerHero.describe(hero.tiles[current.id]?.frame)), page "
                 + "\(ViewerHero.describe(layout.frames[current.id])), viewport \(ViewerHero.describe(hero.viewport))")
        let move = motion.startOpening()
        Task { @MainActor in
            stage()
            hero.log("grows \(current.id) to page \(ViewerHero.describe(layout.frames[current.id]))")
            driver.run(duration: DesignTokens.Duration.viewerTransition, curve: curve(fromDrag: false)) { way in
                hero.progress = 1 - way
            } completion: {
                _ = motion.finish(move)
            }
        }
    }

    func dragged(_ translation: CGSize) {
        let wasDragging = motion.phase == .dragging
        guard motion.drag() else { return }
        if !wasDragging { stage() }
        hero.drag = translation.height
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
        let from = hero.drag
        driver.run(duration: DesignTokens.Duration.viewerTransition, curve: curve(fromDrag: true)) { way in
            hero.drag = from * (1 - way)
        } completion: {
            _ = motion.finish(move)
        }
    }

    /// Back onto the tile of the page on screen.
    func close() {
        guard let move = motion.startClosing() else { return }
        stage()
        hero.landing = tile?.frame
        let (fromProgress, fromDrag) = (hero.progress, hero.drag)
        hero.log("closes \(current.id) onto tile \(ViewerHero.describe(hero.landing)), dragged \(Int(fromDrag))")
        driver.run(duration: DesignTokens.Duration.viewerTransition, curve: curve(fromDrag: fromDrag != 0)) { way in
            hero.progress = fromProgress + (1 - fromProgress) * way
            if fromDrag != 0 { hero.drag = fromDrag * (1 - way) }
        } completion: {
            guard motion.finish(move) else { return }
            followTileThenLeave()
        }
    }

    /// The chat moved under the closing picture (a line arrived, the keyboard went): the picture catches its tile up
    /// before the chat takes over, rather than the tile jumping into place after.
    private func followTileThenLeave() {
        guard let landing = hero.landing, let now = hero.tiles[current.id]?.frame,
              abs(now.minX - landing.minX) + abs(now.minY - landing.minY) > 1 else {
            handOver()
            return
        }
        hero.log("tile of \(current.id) moved while closing to \(ViewerHero.describe(now)); following")
        driver.run(duration: DesignTokens.Duration.fast, curve: .easeOut) { way in
            hero.landing = ViewerGeometry.mix(landing, now, way)
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

    /// Takes the cover away without its slide, and the chat's half of the picture with it: the viewer has already drawn
    /// its going.
    private func leave() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            dismiss()
            hero.endMove()
        }
    }
}
