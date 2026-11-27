import SwiftUI

/// Which chips the compact type pickers offer, and in which of their two rows; a pure rule so tests pin it as one.
nonisolated enum EventTypeChipSubset {
    struct Visible: Equatable {
        /// The first row: the head of the list plus every selected known type, or every match while searching.
        let types: [EventType]
        /// The second row once expanded: every other known type, in the known order; empty otherwise.
        let rest: [EventType]
        /// "See all" trailing the first row while collapsed.
        let showsExpander: Bool
        /// "Show less" trailing the rest once expanded; a search needs neither control.
        let showsCollapser: Bool
    }

    /// A non-empty query shows every match in the first row and no control (a search already reaches the whole list).
    /// Otherwise the first row is the first `collapsedTypeChipCount` of `EventType.known` plus every selected known type
    /// not among them, in the known order, so a choice is never hidden; collapsed, "See all" trails it; expanded, the
    /// first row stays exactly as it was and every other known type follows as the rest, "Show less" trailing. An
    /// unknown selection stays unoffered, like everywhere a type is listed.
    static func visible(matching query: String, expanded: Bool, selected: Set<EventType>) -> Visible {
        guard query.trimmed.isEmpty else {
            return Visible(types: EventType.known.filter { $0.displayName.matchesSearch(query) },
                           rest: [],
                           showsExpander: false,
                           showsCollapser: false)
        }
        var types = Array(EventType.known.prefix(DesignTokens.Layout.collapsedTypeChipCount))
        for type in EventType.known where selected.contains(type) && !types.contains(type) {
            types.append(type)
        }
        guard expanded else { return Visible(types: types, rest: [], showsExpander: true, showsCollapser: false) }
        return Visible(types: types,
                       rest: EventType.known.filter { !types.contains($0) },
                       showsExpander: false,
                       showsCollapser: true)
    }

    /// The single-select form the edit form uses.
    static func visible(matching query: String, expanded: Bool, selected: EventType?) -> Visible {
        visible(matching: query, expanded: expanded, selected: Set(selected.map { [$0] } ?? []))
    }
}

/// The edit form's compact type choice, captioned: a search field over the chips, the head of the list plus the
/// current choice until "See all" lists the rest and "Show less" folds it back; while the search is non-empty every
/// match shows, with the wizard's one-line empty state when nothing does. In a `Form` the picker is two rows:
/// unfolding inserts the second instead of resizing the first, since a `Form` row that resizes slides its own content
/// around whatever the transaction says. The chips are `EventTypeChips`, so the look stays the filter sheet's.
struct EventTypeCompactPicker: View {
    let caption: String
    let selected: EventType
    let onSelect: (EventType) -> Void
    @State private var query = ""
    @State private var expanded = false
    /// The choice the first row was built from when the list unfolded, so a pick in the rest moves no chip.
    @State private var pinned: EventType?

    var body: some View {
        // Hoisted: both rows read it.
        let visible = EventTypeChipSubset.visible(matching: query, expanded: expanded, selected: pinned ?? selected)
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text(caption)
                .font(LilyTheme.Fonts.caption)
                .foregroundStyle(.secondary)
            TypeSearchField(query: $query, identifier: AccessibilityIdentifiers.draftTypeSearch)
            if visible.types.isEmpty {
                TypeSearchNoMatch()
            } else {
                EventTypeChips(types: visible.types,
                               isSelected: { $0 == selected },
                               onSelect: select,
                               identifier: AccessibilityIdentifiers.draftType(_:),
                               expandTitle: visible.expanderTitle,
                               expandIdentifier: AccessibilityIdentifiers.draftTypeExpand,
                               expanderHidden: visible.showsCollapser,
                               onExpand: toggleFold)
            }
        }
        .typeFoldHeadRow(hasRest: !visible.rest.isEmpty)
        if !visible.rest.isEmpty {
            EventTypeChips(types: visible.rest,
                           isSelected: { $0 == selected },
                           onSelect: select,
                           identifier: AccessibilityIdentifiers.draftType(_:),
                           expandTitle: AppBranding.Groups.showLess,
                           expandIdentifier: AccessibilityIdentifiers.draftTypeExpand,
                           onExpand: toggleFold)
                .typeFoldRestRow()
        }
    }

    private func select(_ type: EventType?) {
        if let type { onSelect(type) }
    }

    private func toggleFold() {
        withoutAnimation {
            expanded.toggle()
            pinned = expanded ? selected : nil
        }
    }
}

#Preview {
    ContentScreen {
        Form {
            Section {
                EventTypeCompactPicker(caption: "Event type", selected: .padel) { _ in }
            }
        }
        .scrollContentBackground(.hidden)
    }
}

/// The filter's compact type choice: the same search, rows and fold as the edit form's picker, but multi-select, with
/// the leading "Any type" chip clearing the selection; chosen types join the first row so a choice is never hidden.
struct EventTypeMultiCompactPicker: View {
    let anyTitle: String
    let anyIdentifier: String
    let selected: Set<EventType>
    let onSelectAny: () -> Void
    let onToggle: (EventType) -> Void
    @State private var query = ""
    @State private var expanded = false
    /// The selection the first row was built from when the list unfolded, so a pick in the rest moves no chip.
    @State private var pinned: Set<EventType>?

    var body: some View {
        let visible = EventTypeChipSubset.visible(matching: query, expanded: expanded, selected: pinned ?? selected)
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            TypeSearchField(query: $query, identifier: AccessibilityIdentifiers.filterTypeSearch)
            if visible.types.isEmpty {
                TypeSearchNoMatch()
            } else {
                EventTypeChips(anyTitle: anyTitle,
                               anyIdentifier: anyIdentifier,
                               types: visible.types,
                               isSelected: isSelected,
                               onSelect: select,
                               identifier: AccessibilityIdentifiers.filterType(_:),
                               expandTitle: visible.expanderTitle,
                               expandIdentifier: AccessibilityIdentifiers.filterTypeExpand,
                               expanderHidden: visible.showsCollapser,
                               onExpand: toggleFold)
            }
        }
        .typeFoldHeadRow(hasRest: !visible.rest.isEmpty)
        if !visible.rest.isEmpty {
            EventTypeChips(types: visible.rest,
                           isSelected: isSelected,
                           onSelect: select,
                           identifier: AccessibilityIdentifiers.filterType(_:),
                           expandTitle: AppBranding.Groups.showLess,
                           expandIdentifier: AccessibilityIdentifiers.filterTypeExpand,
                           onExpand: toggleFold)
                .typeFoldRestRow()
        }
    }

    private func isSelected(_ type: EventType?) -> Bool {
        type.map(selected.contains) ?? selected.isEmpty
    }

    private func select(_ type: EventType?) {
        if let type { onToggle(type) } else { onSelectAny() }
    }

    private func toggleFold() {
        withoutAnimation {
            expanded.toggle()
            pinned = expanded ? selected : nil
        }
    }
}

/// The wizard's one-line empty state under a search no type name contains.
private struct TypeSearchNoMatch: View {
    var body: some View {
        Text(AppBranding.Create.typeSearchNoMatch)
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }
}

private extension EventTypeChipSubset.Visible {
    /// The first row's trailing chip: "See all" while collapsed, and kept but hidden once expanded, so the row keeps
    /// its height; nothing while a search shows every match.
    var expanderTitle: String? {
        showsExpander || showsCollapser ? AppBranding.Groups.seeAll : nil
    }
}

private extension View {
    /// The first row: flush bottom while the rest hangs under it, and no separator between the two. Everything stays
    /// inside each row's own bounds: a cell clips on the device, so nothing may draw over the neighbouring row.
    func typeFoldHeadRow(hasRest: Bool) -> some View {
        listRowInsets(.bottom, hasRest ? 0 : nil)
            .listRowSeparator(hasRest ? .hidden : .automatic, edges: .bottom)
    }

    /// The rest of the list, a row of its own, flush under the first.
    func typeFoldRestRow() -> some View {
        listRowInsets(.top, 0)
            .listRowSeparator(.hidden, edges: .top)
    }
}
