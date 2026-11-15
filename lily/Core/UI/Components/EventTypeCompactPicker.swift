import SwiftUI

/// Which chips the edit form's compact type picker offers; a pure rule so tests pin it as one.
nonisolated enum EventTypeChipSubset {
    struct Visible: Equatable {
        let types: [EventType]
        let showsExpander: Bool
    }

    /// A non-empty query shows every match and no expander (a search already reaches the whole list); an expanded
    /// picker shows every known type; a collapsed one the first `collapsedTypeChipCount` of `EventType.known` plus
    /// the selection when it is a known type not among them, so the choice is never hidden, with the expander
    /// trailing. An unknown selection stays unoffered, like everywhere a type is listed.
    static func visible(matching query: String, expanded: Bool, selected: EventType?) -> Visible {
        guard query.trimmed.isEmpty else {
            return Visible(types: EventType.known.filter { $0.displayName.matchesSearch(query) }, showsExpander: false)
        }
        guard !expanded else { return Visible(types: EventType.known, showsExpander: false) }
        var types = Array(EventType.known.prefix(DesignTokens.Layout.collapsedTypeChipCount))
        if let selected, EventType.known.contains(selected), !types.contains(selected) {
            types.append(selected)
        }
        return Visible(types: types, showsExpander: true)
    }
}

/// The edit form's compact type choice: a search field over the chips, only the head of the list plus the current
/// choice until "See all" expands the full flow for the sheet's life (no collapse control); while the search is
/// non-empty every match shows, with the wizard's one-line empty state when nothing does. The chips are
/// `EventTypeChips`, so the look and the selection stay the filter sheet's.
struct EventTypeCompactPicker: View {
    let selected: EventType
    let onSelect: (EventType) -> Void
    @State private var query = ""
    @State private var expanded = false

    var body: some View {
        // Hoisted: three reads per body pass.
        let visible = EventTypeChipSubset.visible(matching: query, expanded: expanded, selected: selected)
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            TypeSearchField(query: $query, identifier: AccessibilityIdentifiers.draftTypeSearch)
            if visible.types.isEmpty {
                Text(AppBranding.Create.typeSearchNoMatch)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                EventTypeChips(types: visible.types,
                               isSelected: { $0 == selected },
                               onSelect: { type in if let type { onSelect(type) } },
                               identifier: AccessibilityIdentifiers.draftType(_:),
                               expandTitle: visible.showsExpander ? AppBranding.Groups.seeAll : nil,
                               expandIdentifier: AccessibilityIdentifiers.draftTypeExpand,
                               onExpand: { expanded = true })
            }
        }
    }
}

#Preview {
    ContentScreen {
        EventTypeCompactPicker(selected: .padel) { _ in }
            .padding()
    }
}
