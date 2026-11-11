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

    /// Secondary action look: plain glass capsule at the native large size, or at `controlSize` where a capsule sits
    /// inside a row or a card (`.regular` beside a 40pt avatar). `.glass` colours its label (text, symbols and
    /// spinner) from the tint: the accent by default, or `labelColor` where the label should read as ink.
    /// (`tint(nil)` would not restore the accent; it leaves the label in the primary colour.)
    func lilyGlassButton(sizing: ButtonSizing = .flexible,
                         controlSize: ControlSize? = .large,
                         labelColor: Color? = nil) -> some View {
        buttonStyle(.glass)
            .tint(labelColor ?? .accentColor)
            .lilyButtonMetrics(sizing: sizing, controlSize: controlSize)
    }

    /// The floating action look (the "+" on Explore): a prominent glass circle in the accent colour. The circle takes its
    /// diameter from the extra-large control size, never from a frame on the label, like every other button, then scales
    /// up slightly (`floatingButtonScale`, the owner's fourth design round) — the transform grows the drawn circle and
    /// its hit area together, the one way to a size between the fixed control sizes.
    func lilyFloatingActionButton() -> some View {
        lilyIconButton(controlSize: .extraLarge)
            .scaleEffect(DesignTokens.Layout.floatingButtonScale)
    }

    /// A glyph in a prominent glass circle (Send in the chat composer). At `.large` the circle stands as tall as a
    /// `lilyField()`, so the two read as one row.
    func lilyIconButton(controlSize: ControlSize = .large) -> some View {
        buttonStyle(.glassProminent)
            .tint(Color.lilyAccent)
            .buttonBorderShape(.circle)
            .controlSize(controlSize)
    }

    /// A glyph in a plain glass circle, the quiet sibling of `lilyIconButton()`: the attach menu beside the composer's
    /// field, the viewer's Close and Share. The label reads as ink, like every glass button that is not a call to action.
    func lilyGlassIconButton() -> some View {
        buttonStyle(.glass)
            .tint(Color.lilyInk)
            .buttonBorderShape(.circle)
            .controlSize(.large)
    }

    /// A text-only action ("See all", Reset, "Resend code", the terms' links): the label in ink (the accent reads at
    /// about 3:1 as small text over the aurora, so it never colours one), `.secondary` while disabled, dimmed while
    /// pressed, with the standard 44pt hit area built in. `color` is for a label on another fill (white on the caller's
    /// bubble); the accent stays on marks and the prominent capsule.
    func lilyTextButton(font: Font = LilyTheme.Fonts.button,
                        color: Color = .lilyInk,
                        minHeight: CGFloat = DesignTokens.Layout.controlHeight) -> some View {
        buttonStyle(LilyTextButtonStyle(font: font, color: color, minHeight: minHeight))
    }

    /// A plain text action in an iOS 26 toolbar (Cancel, Done, Send, Edit): the bar draws the item's glass capsule and
    /// colours the label from the tint, so the ink goes in through the tint. A `.borderless` or custom style there
    /// collapses the item to an icon-sized circle (`DraftSheet` records the "Ca…"), and the bar still dims a disabled
    /// tinted label itself.
    func lilyToolbarTextButton() -> some View {
        tint(Color.lilyInk)
    }
}

/// The look behind `lilyTextButton(font:color:minHeight:)`. A style rather than a `.borderless` button with an explicit
/// foreground style, because an explicit style would never dim: the disabled look needs `isEnabled` read here.
struct LilyTextButtonStyle: ButtonStyle {
    let font: Font
    let color: Color
    let minHeight: CGFloat
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(font)
            .foregroundStyle(isEnabled ? AnyShapeStyle(color) : AnyShapeStyle(.secondary))
            .opacity(configuration.isPressed ? DesignTokens.Opacity.pressedTextButton : 1)
            .tappableLabel(minHeight: minHeight)
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
