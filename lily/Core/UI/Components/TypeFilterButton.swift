import SwiftUI

/// Toolbar button that drops the event-type chips down as a popover (a dropdown, never a chip row on the page): the
/// one criterion of Discover groups and Discover tournaments. The glyph fills while a type is chosen.
struct TypeFilterButton: View {
    @Binding var typeFilter: EventType?
    let identifier: String

    private typealias Copy = AppBranding.Events.Filter

    var body: some View {
        FilterDropdownButton(title: Copy.eventType, isActive: typeFilter != nil, identifier: identifier) { dismiss in
            TypeFilterPanel(typeFilter: $typeFilter, onDone: dismiss)
        }
    }
}

/// The one Discover criterion: a single event type, or any.
struct TypeFilterPanel: View {
    @Binding var typeFilter: EventType?
    let onDone: () -> Void

    private typealias Copy = AppBranding.Events.Filter

    var body: some View {
        DropdownPanel(title: Copy.eventType, onDone: onDone) {
            EventTypeChips(anyTitle: Copy.anyType, isSelected: { $0 == typeFilter }, onSelect: { typeFilter = $0 })
        }
    }
}

#Preview {
    @Previewable @State var type: EventType? = .padel
    TypeFilterPanel(typeFilter: $type) {}
}
