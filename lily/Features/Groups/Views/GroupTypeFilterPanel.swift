import SwiftUI

/// Toolbar button on Discover that drops the type chips down as a popover (a dropdown, never a chip row on the
/// page). The glyph fills while a type is chosen.
struct GroupTypeFilterButton: View {
    let viewModel: GroupListViewModel
    @State private var isPresented = false

    private typealias Copy = AppBranding.Events.Filter

    var body: some View {
        Button {
            isPresented = true
        } label: {
            Label(Copy.eventType, systemImage: iconName)
        }
        .accessibilityIdentifier(AccessibilityIdentifiers.groupsTypeFilter)
        .accessibilityValue(viewModel.typeFilter == nil ? Copy.inactiveValue : Copy.activeValue)
        .popover(isPresented: $isPresented, arrowEdge: .top) {
            GroupTypeFilterPanel(viewModel: viewModel) { isPresented = false }
                .presentationCompactAdaptation(.popover)
        }
    }

    private var iconName: String {
        viewModel.typeFilter == nil ? DesignTokens.Symbols.filter : DesignTokens.Symbols.filterActive
    }
}

/// The one Discover criterion: a single event type, or any.
struct GroupTypeFilterPanel: View {
    @Bindable var viewModel: GroupListViewModel
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
            EventTypeChips(anyTitle: Copy.anyType,
                           isSelected: { $0 == viewModel.typeFilter },
                           onSelect: { viewModel.typeFilter = $0 })
        }
        .padding(DesignTokens.Spacing.lg)
        .frame(width: DesignTokens.Layout.filterPanelWidth)
        .presentationBackground(.clear)
        .tint(Color.lilyAccent)
    }
}

#Preview {
    GroupTypeFilterPanel(viewModel: AppDependencies.makeMock().makeGroupListViewModel(scope: .discover)) {}
}
