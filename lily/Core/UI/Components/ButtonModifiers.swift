import SwiftUI

extension View {
    /// The app's primary call-to-action look: prominent glass capsule in the accent color.
    func lilyProminentButton() -> some View {
        buttonStyle(.glassProminent)
            .buttonBorderShape(.capsule)
            .tint(Color.lilyAccent)
    }

    /// Secondary action look: plain glass capsule.
    func lilyGlassButton() -> some View {
        buttonStyle(.glass)
            .buttonBorderShape(.capsule)
    }

    /// Stretches a button label to the full width at the standard button height.
    func fullWidthButtonLabel() -> some View {
        font(LilyTheme.Fonts.button)
            .frame(maxWidth: .infinity)
            .frame(height: DesignTokens.Layout.buttonHeight)
    }
}
