import SwiftUI

/// The "lily" wordmark used on the launch and welcome screens.
struct Wordmark: View {
    var body: some View {
        Text("lily")
            .font(LilyTheme.Fonts.wordmark)
            .tracking(DesignTokens.Typography.wordmarkTracking)
            .foregroundStyle(Color.lilyInk)
    }
}
