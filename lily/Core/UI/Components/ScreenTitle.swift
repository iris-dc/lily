import SwiftUI

/// Large section title with tight tracking, used on every top-level screen.
struct ScreenTitle: View {
    let text: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Text(text)
                .font(LilyTheme.Fonts.screenTitle)
                .tracking(DesignTokens.Typography.titleTracking)
            if let subtitle {
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
