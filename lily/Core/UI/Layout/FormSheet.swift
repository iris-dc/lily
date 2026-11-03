import SwiftUI

extension View {
    /// The sizing of a sheet that is a form (create, edit, sign in, invite, report, a match's actions): a centred form
    /// sheet on a regular width instead of a page as wide as the screen. A compact width ignores the sizing and keeps
    /// the sheet's detents, so the iPhone is unchanged.
    func lilyFormSheet() -> some View {
        presentationSizing(.form)
    }

    /// `lilyFormSheet()` for a sheet that writes: the grabber is the hint that a swipe closes it, the swipe is refused
    /// while a write is out so its outcome is never unknown, and the popup is mounted here because a sheet is drawn
    /// above the root's.
    func lilyFormSheet(errorCenter: ErrorCenter, lockedWhile isBusy: Bool) -> some View {
        lilyFormSheet()
            .presentationDragIndicator(.visible)
            .interactiveDismissDisabled(isBusy)
            .errorPopup(errorCenter)
    }
}
