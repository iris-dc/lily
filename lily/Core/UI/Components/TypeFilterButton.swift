import SwiftUI

/// Toolbar button that drops the event-type chips down as a popover (a dropdown, never a chip row on the page): the
/// one criterion of Discover groups and Discover tournaments. The glyph fills while a type is chosen.
struct TypeFilterButton: View {
    @Binding var typeFilter: EventType?
    let identifier: String
    @State private var isPresented = false

    private typealias Copy = AppBranding.Events.Filter

    var body: some View {
        Button {
            isPresented = true
        } label: {
            Label(Copy.eventType, systemImage: iconName)
        }
        .accessibilityIdentifier(identifier)
        .accessibilityValue(typeFilter == nil ? Copy.inactiveValue : Copy.activeValue)
        .popover(isPresented: $isPresented, arrowEdge: .top) {
            TypeFilterPanel(typeFilter: $typeFilter) { isPresented = false }
                .presentationCompactAdaptation(.popover)
        }
    }

    private var iconName: String {
        typeFilter == nil ? DesignTokens.Symbols.filter : DesignTokens.Symbols.filterActive
    }
}

/// The one Discover criterion: a single event type, or any.
struct TypeFilterPanel: View {
    @Binding var typeFilter: EventType?
    let onDone: () -> Void

    private typealias Copy = AppBranding.Events.Filter

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            HStack {
                Text(Copy.eventType).font(LilyTheme.Fonts.cardTitle)
                Spacer()
                Button(Copy.done, action: onDone)
                    .lilyProminentButton(sizing: .fitted, controlSize: .small)
            }
            EventTypeChips(anyTitle: Copy.anyType, isSelected: { $0 == typeFilter }, onSelect: { typeFilter = $0 })
        }
        .padding(DesignTokens.Spacing.lg)
        .frame(width: DesignTokens.Layout.filterPanelWidth)
        .presentationBackground(.clear)
        .tint(Color.lilyAccent)
    }
}

#Preview {
    @Previewable @State var type: EventType? = .padel
    TypeFilterPanel(typeFilter: $type) {}
}
