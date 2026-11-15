import SwiftUI

/// One `ChoiceChip` per offered event type in a flow, optionally led by an "any" chip (`nil` in the closures) and
/// ended by an expander chip when a caller narrows the offer (the edit form's compact picker). The caller owns the
/// selection, so the same chips serve a single choice (a draft's type), a multiple choice (the Explore filter) and
/// a nullable one (a group's type).
struct EventTypeChips: View {
    var anyTitle: String?
    var anyIdentifier: String?
    /// The types to offer; every known type unless the caller narrows the flow.
    var types: [EventType] = EventType.known
    let isSelected: (EventType?) -> Bool
    let onSelect: (EventType?) -> Void
    var identifier: ((EventType) -> String)?
    /// The trailing expander chip ("See all"), shown while set; it widens the offer instead of choosing.
    var expandTitle: String?
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
                ChoiceChip(title: expandTitle, isSelected: false) { onExpand?() }
                    .accessibilityIdentifier(expandIdentifier ?? "")
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
