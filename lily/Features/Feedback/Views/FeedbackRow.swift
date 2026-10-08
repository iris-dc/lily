import SwiftUI

/// The way to the contact form on Profile, for guests and users alike (a guest is sent to sign in first, as for every
/// write): a glass card with the title, what it is for and a chevron, laid out like the language row above it.
struct FeedbackRow: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            GlassCard {
                HStack(spacing: DesignTokens.Spacing.md) {
                    Label {
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                            Text(AppBranding.Feedback.rowTitle)
                            Text(AppBranding.Feedback.rowSubtitle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: DesignTokens.Symbols.feedback)
                    }
                    Spacer()
                    Image(systemName: DesignTokens.Symbols.chevron)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
        .lilyHoverable()
        .accessibilityIdentifier(AccessibilityIdentifiers.profileFeedback)
    }
}

#Preview {
    ContentScreen {
        FeedbackRow {}
            .padding(DesignTokens.Layout.screenMargin)
    }
}
