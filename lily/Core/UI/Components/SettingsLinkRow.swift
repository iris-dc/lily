import SwiftUI

/// A settings link as one glass card: an icon, the title, a line on what it is for and a chevron, the whole card the
/// button. Profile's display name, "About you" and contact rows share it; a subtitle longer than its lines (the bio) is
/// cut. A thin wrapper over `GlassNavigationRow`, which the creation wizard shares.
struct SettingsLinkRow: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let identifier: String
    let action: () -> Void

    var body: some View {
        GlassNavigationRow(title: title,
                           subtitle: subtitle,
                           systemImage: systemImage,
                           identifier: identifier,
                           action: action)
    }
}
