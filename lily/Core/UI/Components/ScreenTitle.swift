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
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
