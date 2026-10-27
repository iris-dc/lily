import SwiftUI

/// One option of a poll as a pill: a ring, the text and the share's number at the trailing edge, reserved before it
/// shows; once the caller voted the share fills the pill from the leading edge. One height in every state, so a vote
/// moves no row of the transcript; a tap is the poll's to take (`onTap`), with a press dimming the pill.
struct PollOptionPill: View {
    let option: Poll.Option
    let display: PollOptionDisplay
    let own: Bool
    let onTap: () -> Void
    /// The share's column grows with the type, or "100%" would be cut at accessibility sizes.
    @ScaledMetric(relativeTo: .footnote) private var shareWidth = DesignTokens.Layout.pollShareWidth

    private var ink: BubbleInk { BubbleInk(own: own) }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: display.isMarked ? DesignTokens.Symbols.pollChosen : DesignTokens.Symbols.pollChoice)
                    .foregroundStyle(display.isMarked ? ink.accent : ink.secondary)
                    .contentTransition(.symbolEffect(.replace))
                    .accessibilityLabel(display.isMarked ? Text(AppBranding.Chat.Polls.chosen) : Text(verbatim: ""))
                Text(verbatim: option.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(display.share, format: .percent.precision(.fractionLength(0)))
                    .font(.footnote.weight(.semibold).monospacedDigit())
                    .frame(width: shareWidth, alignment: .trailing)
                    .opacity(display.showsShare ? 1 : 0)
                    .contentTransition(.numericText())
                    .accessibilityHidden(!display.showsShare)
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .frame(minHeight: DesignTokens.Layout.pollOptionMinHeight)
            .background {
                ZStack(alignment: .leading) {
                    track
                    fill.scaleEffect(x: display.showsShare ? display.share : 0, y: 1, anchor: .leading)
                }
            }
            .clipShape(.rect(cornerRadius: DesignTokens.Radius.pollPill))
            .contentShape(.rect)
        }
        .buttonStyle(PollPillButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(display.isMarked ? .isSelected : [])
    }

    private var track: Color {
        own ? Color.white.opacity(DesignTokens.Opacity.pollTrackOnAccent) : Color.lilyInk.opacity(DesignTokens.Opacity.pollTrack)
    }

    private var fill: Color {
        own ? Color.lilyAccentDeep.opacity(DesignTokens.Opacity.pollFillOnAccent)
            : Color.lilyAccent.opacity(DesignTokens.Opacity.pollFill)
    }
}

/// A pill dims while pressed and keeps its look when disabled: a voted poll's pills are no longer buttons to tap, but
/// they are its results, not greyed-out controls.
private struct PollPillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? DesignTokens.Opacity.pollPressed : 1)
            .animation(.easeOut(duration: DesignTokens.Duration.fast), value: configuration.isPressed)
    }
}
