import SwiftUI

/// Which chips the compact type pickers offer; a pure rule so tests pin it as one.
nonisolated enum EventTypeChipSubset {
    struct Visible: Equatable {
        /// The head of the list plus every selected known type, or every match while searching.
        let types: [EventType]
        /// The rest of the list once expanded, appended after `types` in the same flow so no chip relocates; empty
        /// otherwise.
        let rest: [EventType]
        /// "See all" while collapsed.
        let showsExpander: Bool
        /// "Show less" once expanded; a search needs neither control.
        let showsCollapser: Bool
    }

    /// A non-empty query shows every match and no control (a search already reaches the whole list). Otherwise the
    /// head is the first `collapsedTypeChipCount` of `EventType.known` plus every selected known type not among them,
    /// in the known order, so a choice is never hidden; collapsed, "See all" trails it; expanded, the head stays
    /// exactly as it was and every other known type follows as the rest, "Show less" trailing. An unknown selection
    /// stays unoffered, like everywhere a type is listed.
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

/// The edit form's compact type choice, captioned: a search field over one chip flow, the head of the list plus the
/// current choice until "See all" appends the rest and "Show less" folds it back; while the search is non-empty every
/// match shows, with the wizard's one-line empty state when nothing does. One `Form` row whose identity folds with it
/// (see `typeFold`), so the section can never split and nothing slides. The chips are `EventTypeChips`, so the look
/// stays the filter sheet's.
struct EventTypeCompactPicker: View {
    let caption: String
    let selected: EventType
    let onSelect: (EventType) -> Void
    @State private var query = ""
    @State private var expanded = false
    /// The choice the head was built from when the list unfolded, so a pick in the rest moves no chip until a fold.
    @State private var pinned: EventType?

    var body: some View {
        let visible = EventTypeChipSubset.visible(matching: query, expanded: expanded, selected: pinned ?? selected)
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text(caption)
                .font(LilyTheme.Fonts.caption)
                .foregroundStyle(.secondary)
            TypeSearchField(query: $query, identifier: AccessibilityIdentifiers.draftTypeSearch)
            if visible.types.isEmpty {
                TypeSearchNoMatch()
            } else {
                EventTypeChips(types: visible.types + visible.rest,
                               isSelected: { $0 == selected },
                               onSelect: { type in if let type { onSelect(type) } },
                               identifier: AccessibilityIdentifiers.draftType(_:),
                               expandTitle: visible.foldTitle,
                               expandSymbol: visible.foldSymbol,
                               expandIdentifier: AccessibilityIdentifiers.draftTypeExpand,
                               onExpand: toggleFold)
            }
        }
        .typeFold(expanded)
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

/// The filter's compact type choice: the same search, flow and fold as the edit form's picker, but multi-select, with
/// the leading "Any type" chip clearing the selection; chosen types join the head so a choice is never hidden.
struct EventTypeMultiCompactPicker: View {
    let anyTitle: String
    let anyIdentifier: String
    let selected: Set<EventType>
    let onSelectAny: () -> Void
    let onToggle: (EventType) -> Void
    @State private var query = ""
    @State private var expanded = false
    /// The selection the head was built from when the list unfolded, so a pick in the rest moves no chip until a fold.
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
                               types: visible.types + visible.rest,
                               isSelected: { type in type.map(selected.contains) ?? selected.isEmpty },
                               onSelect: { type in if let type { onToggle(type) } else { onSelectAny() } },
                               identifier: AccessibilityIdentifiers.filterType(_:),
                               expandTitle: visible.foldTitle,
                               expandSymbol: visible.foldSymbol,
                               expandIdentifier: AccessibilityIdentifiers.filterTypeExpand,
                               onExpand: toggleFold)
            }
        }
        .typeFold(expanded)
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
    /// The fold toggle's face: "See all" while collapsed, "Show less" once expanded, nothing while a search already
    /// shows every match.
    var foldTitle: String? {
        if showsExpander { return AppBranding.Groups.seeAll }
        if showsCollapser { return AppBranding.Groups.showLess }
        return nil
    }

    var foldSymbol: String {
        showsCollapser ? DesignTokens.Symbols.chevronUp : DesignTokens.Symbols.chevronDown
    }
}

private extension View {
    /// The fold, as one `Form` row whose identity changes with it: the `Form` then replaces the cell at its new height
    /// in the same non-animated update, instead of self-size-animating the old cell, which slid the chips on the
    /// device whatever the transaction said. One cell also means one continuous card: the list can never show a seam.
    func typeFold(_ expanded: Bool) -> some View {
        id(expanded)
    }
}
