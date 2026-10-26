import SwiftUI

/// A setting on Profile as one card that is a menu button: the setting's name, its current value and the chevrons,
/// the whole card taking the tap (the value alone was a small target at the trailing edge). The menu's items are a
/// `Picker`, so they carry the checkmark; the value is drawn here, since a `Picker` button repeats the chosen item's
/// full text ("PLN · Polish Zloty" wrapped the row to two lines).
struct SettingsMenuRow<Items: View>: View {
    let title: String
    let systemImage: String
    let value: String
    @ViewBuilder let items: () -> Items

    var body: some View {
        Menu(content: items) {
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
                .foregroundStyle(.primary)
            }
        }
        // The default menu button tints its whole label; plain keeps the text white and the chevrons accent.
        .menuStyle(.button)
        .buttonStyle(.plain)
    }
}
