import SwiftUI

/// The app wordmark. Text comes from `AppBranding`; size is a parameter so launch and landing can differ.
struct Wordmark: View {
    var size: CGFloat = DesignTokens.Typography.wordmarkSize

    var body: some View {
        Text(AppBranding.name)
            .font(.system(size: size, weight: .semibold))
            .tracking(DesignTokens.Typography.wordmarkTracking * size / DesignTokens.Typography.wordmarkSize)
            .foregroundStyle(Color.lilyInk)
    }
}
