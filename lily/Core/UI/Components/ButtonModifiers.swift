import SwiftUI

extension View {
    /// The app's primary call-to-action look: prominent glass capsule in the accent color at the native large size.
    /// `.flexible` fills the available width, `.fitted` hugs the label.
    func lilyProminentButton(sizing: ButtonSizing = .flexible, controlSize: ControlSize = .large) -> some View {
        buttonStyle(.glassProminent)
            .tint(Color.lilyAccent)
            .lilyButtonMetrics(sizing: sizing, controlSize: controlSize)
    }

    /// Secondary action look: plain glass capsule at the native large size. `.glass` colours its label (text, symbols
    /// and spinner) from the tint: the accent by default, or `labelColor` where the label should read as ink.
    /// (`tint(nil)` would not restore the accent; it leaves the label in the primary colour.)
    func lilyGlassButton(sizing: ButtonSizing = .flexible, labelColor: Color? = nil) -> some View {
        buttonStyle(.glass)
            .tint(labelColor ?? .accentColor)
            .lilyButtonMetrics(sizing: sizing, controlSize: .large)
    }
}

private extension View {
    /// Height and padding come from the control size and sizing, never from a frame on the label, so the
    /// capsule matches every other iOS 26 button and still grows with Dynamic Type. The size is a parameter because a
    /// `.controlSize` applied outside this modifier would lose to the one applied here.
    func lilyButtonMetrics(sizing: ButtonSizing, controlSize: ControlSize) -> some View {
        buttonBorderShape(.capsule)
            .controlSize(controlSize)
            .buttonSizing(sizing)
            .font(LilyTheme.Fonts.button)
    }
}
