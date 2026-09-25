import SwiftUI

extension View {
    /// The app's primary call-to-action look: prominent glass capsule in the accent color at the native large size.
    /// `.flexible` fills the available width, `.fitted` hugs the label. `controlSize: nil` keeps the size of the
    /// surroundings, for a toolbar, which sizes its items itself (44pt, matching no control size).
    func lilyProminentButton(sizing: ButtonSizing = .flexible, controlSize: ControlSize? = .large) -> some View {
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

    /// The floating action look (the "+" on Explore): a prominent glass circle in the accent colour. The circle takes its
    /// diameter from the extra-large control size, never from a frame on the label, like every other button.
    func lilyFloatingActionButton() -> some View {
        lilyIconButton(controlSize: .extraLarge)
    }

    /// A glyph in a prominent glass circle (Send in the chat composer). At `.large` the circle stands as tall as a
    /// `lilyField()`, so the two read as one row.
    func lilyIconButton(controlSize: ControlSize = .large) -> some View {
        buttonStyle(.glassProminent)
            .tint(Color.lilyAccent)
            .buttonBorderShape(.circle)
            .controlSize(controlSize)
    }
}

private extension View {
    /// Height and padding come from the control size and sizing, never from a frame on the label, so the
    /// capsule matches every other iOS 26 button and still grows with Dynamic Type. The size is a parameter because a
    /// `.controlSize` applied outside this modifier would lose to the one applied here.
    func lilyButtonMetrics(sizing: ButtonSizing, controlSize: ControlSize?) -> some View {
        buttonBorderShape(.capsule)
            // `.controlSize(_:)` is this environment write; `nil` leaves the inherited size alone.
            .transformEnvironment(\.controlSize) { size in
                if let controlSize { size = controlSize }
            }
            .buttonSizing(sizing)
            .font(LilyTheme.Fonts.button)
    }
}
