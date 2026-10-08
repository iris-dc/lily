import SwiftUI

extension View {
    /// The sizing of a sheet that is a form (create, edit, sign in, invite, report, a match's actions): a centred form
    /// sheet on a regular width instead of a page as wide as the screen. A compact width ignores the sizing and keeps
    /// the sheet's detents, so the iPhone is unchanged.
    func lilyFormSheet() -> some View {
        presentationSizing(.form)
    }
}
