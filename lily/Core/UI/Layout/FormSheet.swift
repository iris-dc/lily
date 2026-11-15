import SwiftUI

extension View {
    /// The sizing of a sheet that is a form (create, edit, sign in, invite, report, a match's actions): a centred form
    /// sheet on a regular width instead of a page as wide as the screen — a compact width ignores the sizing and keeps
    /// the sheet's detents — with the grabber on every width, because it is the hint that a swipe closes the sheet.
    func lilyFormSheet() -> some View {
        presentationSizing(.form)
            .presentationDragIndicator(.visible)
    }

    /// `lilyFormSheet()` for a sheet that writes: the swipe is refused while a write is out so its outcome is never
    /// unknown, and the popup is mounted here because a sheet is drawn above the root's.
    func lilyFormSheet(errorCenter: ErrorCenter, lockedWhile isBusy: Bool) -> some View {
        lilyFormSheet()
            .interactiveDismissDisabled(isBusy)
            .errorPopup(errorCenter)
    }
}
