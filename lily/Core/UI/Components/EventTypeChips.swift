import SwiftUI

/// One `ChoiceChip` per event type in a flow, optionally led by an "any" chip (`nil` in the closures). The caller
/// owns the selection, so the same chips serve a single choice (a draft's type), a multiple choice (the Explore
/// filter) and a nullable one (a group's type).
struct EventTypeChips: View {
    var anyTitle: String?
    var anyIdentifier: String?
    var types: [EventType] = EventType.allCases
    let isSelected: (EventType?) -> Bool
    let onSelect: (EventType?) -> Void
    var identifier: ((EventType) -> String)?

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
        }
    }
}

#Preview {
    ContentScreen {
        EventTypeChips(anyTitle: "Any type", isSelected: { $0 == .padel }, onSelect: { _ in })
            .padding()
    }
}
