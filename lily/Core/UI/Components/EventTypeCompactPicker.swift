import SwiftUI

/// Which chips the edit form's compact type picker offers; a pure rule so tests pin it as one.
nonisolated enum EventTypeChipSubset {
    struct Visible: Equatable {
        let types: [EventType]
        let showsExpander: Bool
    }

    /// A non-empty query shows every match and no expander (a search already reaches the whole list); an expanded
    /// picker shows every known type; a collapsed one the first `collapsedTypeChipCount` of `EventType.known` plus
    /// every selected known type not among them, in the known order, so a choice is never hidden, with the expander
    /// trailing. An unknown selection stays unoffered, like everywhere a type is listed.
    static func visible(matching query: String, expanded: Bool, selected: Set<EventType>) -> Visible {
        guard query.trimmed.isEmpty else {
            return Visible(types: EventType.known.filter { $0.displayName.matchesSearch(query) }, showsExpander: false)
        }
        guard !expanded else { return Visible(types: EventType.known, showsExpander: false) }
        var types = Array(EventType.known.prefix(DesignTokens.Layout.collapsedTypeChipCount))
        for type in EventType.known where selected.contains(type) && !types.contains(type) {
            types.append(type)
        }
        return Visible(types: types, showsExpander: true)
    }

    /// The single-select form the edit form uses.
    static func visible(matching query: String, expanded: Bool, selected: EventType?) -> Visible {
        visible(matching: query, expanded: expanded, selected: Set(selected.map { [$0] } ?? []))
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

/// The filter's compact type choice: the same search, head-of-list and "See all" flow as the edit form's picker, but
/// multi-select, with the leading "Any type" chip clearing the selection; chosen types join the collapsed head so a
/// choice is never hidden.
struct EventTypeMultiCompactPicker: View {
    let anyTitle: String
    let anyIdentifier: String
    let selected: Set<EventType>
    let onSelectAny: () -> Void
    let onToggle: (EventType) -> Void
    @State private var query = ""
    @State private var expanded = false

    var body: some View {
        let visible = EventTypeChipSubset.visible(matching: query, expanded: expanded, selected: selected)
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            TypeSearchField(query: $query, identifier: AccessibilityIdentifiers.filterTypeSearch)
            if visible.types.isEmpty {
                Text(AppBranding.Create.typeSearchNoMatch)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                EventTypeChips(anyTitle: anyTitle,
                               anyIdentifier: anyIdentifier,
                               types: visible.types,
                               isSelected: { type in type.map(selected.contains) ?? selected.isEmpty },
                               onSelect: { type in
                                   if let type { onToggle(type) } else { onSelectAny() }
                               },
                               identifier: AccessibilityIdentifiers.filterType(_:),
                               expandTitle: visible.showsExpander ? AppBranding.Groups.seeAll : nil,
                               expandIdentifier: AccessibilityIdentifiers.filterTypeExpand,
                               onExpand: { expanded = true })
            }
        }
    }
}
