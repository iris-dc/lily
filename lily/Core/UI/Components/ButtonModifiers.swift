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
    /// The height is a minimum, so labels that wrap at large Dynamic Type sizes grow the capsule instead of spilling out.
    func fullWidthButtonLabel() -> some View {
        font(LilyTheme.Fonts.button)
            .frame(maxWidth: .infinity, minHeight: DesignTokens.Layout.buttonHeight)
    }

    /// Gives a plain text button a finger-sized hit area without changing how the text looks.
    func tappableTextLabel() -> some View {
        frame(minHeight: DesignTokens.Layout.controlHeight)
            .contentShape(.rect)
    }
}
