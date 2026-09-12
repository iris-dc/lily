import SwiftUI

/// The launch-screen wordmark. Text comes from `AppBranding`; tracking scales with the size the caller passes.
struct Wordmark: View {
    let size: CGFloat

    var body: some View {
        Text(AppBranding.name)
            .font(LilyTheme.Fonts.wordmark(size: size))
            .tracking(DesignTokens.Typography.wordmarkTrackingPerPoint * size)
            .foregroundStyle(Color.lilyInk)
    }
}
