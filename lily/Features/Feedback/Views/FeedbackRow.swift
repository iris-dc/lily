import SwiftUI

/// The way to the contact form on Profile, for guests and users alike (a guest is sent to sign in first, as for every
/// write): the title, what it is for and a chevron, laid out like the language and currency rows above it.
struct FeedbackRow: View {
    let action: () -> Void

    var body: some View {
        SettingsLinkRow(title: AppBranding.Feedback.rowTitle,
                        subtitle: AppBranding.Feedback.rowSubtitle,
                        systemImage: DesignTokens.Symbols.feedback,
                        identifier: AccessibilityIdentifiers.profileFeedback,
                        action: action)
    }
}

#Preview {
    ContentScreen {
        FeedbackRow {}
            .padding(DesignTokens.Layout.screenMargin)
    }
}
