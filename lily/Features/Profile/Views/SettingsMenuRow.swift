import SwiftUI

/// A setting on Profile as one card that opens a menu from a tap anywhere on it: the setting's name, its current value
/// and the chevrons. The card is drawn as plain content under a menu whose label is a transparent shape of the card's
/// size: iOS hides a menu's label while the menu is up and morphs it back on dismissal, so a card that was the label
/// vanished for a few frames at every open and close (the value alone was the label before, and a small target). The
/// menu's items are a `Picker`, so they carry the checkmark; the value is drawn here, since a `Picker` button repeats
/// the chosen item's full text ("PLN · Polish Zloty" wrapped the row to two lines). The menu speaks for the card.
struct SettingsMenuRow<Items: View>: View {
    let title: String
    let systemImage: String
    let value: String
    let identifier: String
    @ViewBuilder let items: () -> Items

    var body: some View {
        GlassCard {
            HStack(spacing: DesignTokens.Spacing.md) {
                Label(title, systemImage: systemImage)
                Spacer()
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Text(verbatim: value)
                        .lineLimit(1)
                        .minimumScaleFactor(DesignTokens.Layout.menuLabelMinimumScale)
                    Image(systemName: DesignTokens.Symbols.menuChevron)
                        .imageScale(.small)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.lilyAccent)
                }
            }
        }
        .accessibilityHidden(true)
        .overlay {
            Menu(content: items) {
                Color.clear.contentShape(.rect)
            }
            .accessibilityLabel(Text(verbatim: "\(title), \(value)"))
            .accessibilityIdentifier(identifier)
        }
    }
}
