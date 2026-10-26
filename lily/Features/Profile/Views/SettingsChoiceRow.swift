import SwiftUI

/// One choice a settings card offers: what it stands for and how the dropdown names it.
struct SettingsChoice<Value: Hashable>: Identifiable {
    let value: Value
    let title: String

    var id: Value { value }
}

/// A setting on Profile as one card that opens its choices as a popover from a tap anywhere on it: the setting's name,
/// its current value and the chevrons, then the choices as rows with a mark on the current one, which a pick or a tap
/// outside closes. The popover opens upward, where Profile has room, and shows whole rows before it scrolls
/// (`dropdownMaxHeight`): opened downward it lay over the floating tab bar with a row cut mid-glyph. A `Menu` was tried
/// first: iOS morphs a menu's label into the menu and back, and with the whole card as the label the card left its slot
/// empty while the menu was up and zoomed back with an overshoot when it closed, while a glass card kept out of the
/// label lost its material under the menu; a popover leaves the card where it is.
struct SettingsChoiceRow<Value: Hashable>: View {
    let title: String
    let systemImage: String
    /// The current choice as the card shows it (the currency's code alone: its full title wrapped the card).
    let value: String
    let identifier: String
    let choices: [SettingsChoice<Value>]
    @Binding var selection: Value
    @State private var isPresented = false
    /// The card's width, which the popover takes up to `dropdownMaxWidth`, so the list lines up with the card.
    @State private var cardWidth: CGFloat?

    var body: some View {
        Button {
            isPresented = true
        } label: {
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
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
        .onGeometryChange(for: CGFloat.self, of: { $0.size.width }, action: { cardWidth = $0 })
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            ScrollView {
                list.padding(.horizontal, DesignTokens.Spacing.lg)
            }
            .frame(width: min(cardWidth ?? DesignTokens.Layout.dropdownMaxWidth, DesignTokens.Layout.dropdownMaxWidth))
            .frame(maxHeight: DesignTokens.Layout.dropdownMaxHeight)
            .presentationBackground(.clear)
            .presentationCompactAdaptation(.popover)
        }
    }

    private var list: some View {
        VStack(spacing: 0) {
            ForEach(choices) { choice in
                Button {
                    isPresented = false
                    selection = choice.value
                } label: {
                    HStack {
                        Text(verbatim: choice.title)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if choice.value == selection {
                            Image(systemName: DesignTokens.Symbols.chosen)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.lilyAccent)
                        }
                    }
                    .tappableLabel()
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(choice.value == selection ? .isSelected : [])
                if choice.id != choices.last?.id {
                    Divider()
                }
            }
        }
    }
}
