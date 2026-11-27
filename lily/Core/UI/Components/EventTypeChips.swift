import SwiftUI

/// One `ChoiceChip` per offered event type in a flow, optionally led by an "any" chip (`nil` in the closures) and
/// ended by the fold toggle when a caller folds the offer (the compact pickers). The caller owns the selection, so
/// the same chips serve a single choice (a draft's type), a multiple choice (the Explore filter) and a nullable one
/// (a group's type).
struct EventTypeChips: View {
    var anyTitle: String?
    var anyIdentifier: String?
    /// The types to offer; every known type unless the caller narrows the flow.
    var types: [EventType] = EventType.known
    let isSelected: (EventType?) -> Bool
    let onSelect: (EventType?) -> Void
    var identifier: ((EventType) -> String)?
    /// The trailing fold toggle ("See all" or "Show less"), shown while set; it changes the offer instead of
    /// choosing, so it is drawn as a quiet text control with an accent chevron, never as another chip.
    var expandTitle: String?
    var expandSymbol: String = DesignTokens.Symbols.chevronDown
    var expandIdentifier: String?
    var onExpand: (() -> Void)?

    var body: some View {
        FlowLayout(spacing: DesignTokens.Spacing.md, rowSpacing: 0) {
            if let anyTitle {
                ChoiceChip(title: anyTitle, isSelected: isSelected(nil)) { onSelect(nil) }
                    .accessibilityIdentifier(anyIdentifier ?? "")
            }
            ForEach(types, id: \.self) { type in
                ChoiceChip(title: type.displayName, systemImage: type.symbolName, isSelected: isSelected(type)) {
                    onSelect(type)
                }
                .accessibilityIdentifier(identifier?(type) ?? "")
            }
            if let expandTitle {
                TypeFoldToggle(title: expandTitle, symbol: expandSymbol) { onExpand?() }
                    .accessibilityIdentifier(expandIdentifier ?? "")
            }
        }
    }
}

/// The fold toggle at the end of the type flow: secondary text beside an accent chevron (the accent goes on the mark,
/// never the text), with a chip-sized hit area but no capsule, so it reads as the control over the list rather than
/// one more type.
struct TypeFoldToggle: View {
    let title: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.Spacing.xs) {
                Text(title)
                    .foregroundStyle(.secondary)
                Image(systemName: symbol)
                    .font(.caption2)
                    .foregroundStyle(Color.lilyAccent)
            }
            .font(LilyTheme.Fonts.caption)
            .padding(.horizontal, DesignTokens.Spacing.xs)
            .tappableLabel()
        }
        .buttonStyle(.plain)
        .lilyHoverable()
    }
}

#Preview {
    ContentScreen {
        EventTypeChips(anyTitle: "Any type",
                       types: Array(EventType.known.prefix(3)),
                       isSelected: { $0 == .padel },
                       onSelect: { _ in },
                       expandTitle: "See all")
            .padding()
    }
}
