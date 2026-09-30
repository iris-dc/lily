import SwiftUI

/// In-content title with tight tracking for pushed and sheet screens (event detail, sign-in).
/// Tab roots use `.navigationTitle` instead.
struct ScreenTitle: View {
    let text: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Text(text)
                .font(LilyTheme.Fonts.screenTitle)
                .tracking(DesignTokens.Typography.titleTracking)
            if let subtitle {
                ScreenSubtitle(text: subtitle)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The line under a `ScreenTitle`, on its own for a screen that makes that line a link (the event detail's host).
struct ScreenSubtitle: View {
    let text: String

    var body: some View {
        Text(text).font(.subheadline).foregroundStyle(.secondary)
    }
}
