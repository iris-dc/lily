import SwiftUI

/// Toolbar button that drops the filter panel down from itself as a popover (kept a popover on iPhone too, so it
/// reads as a dropdown rather than a sheet). The glyph fills while any criterion is active.
struct EventFilterButton: View {
    let viewModel: EventListViewModel
    @State private var isPresented = false

    private typealias Copy = AppBranding.Events.Filter

    var body: some View {
        Button {
            isPresented = true
        } label: {
            Label(Copy.title, systemImage: iconName)
        }
        .accessibilityIdentifier("events-filter")
        // The filled glyph is the only visual cue that the feed is narrowed; VoiceOver needs it as a value.
        .accessibilityValue(viewModel.filter.isActive ? Copy.activeValue : Copy.inactiveValue)
        .popover(isPresented: $isPresented, arrowEdge: .top) {
            EventFilterPanel(viewModel: viewModel) { isPresented = false }
                .presentationCompactAdaptation(.popover)
        }
    }

    private var iconName: String {
        viewModel.filter.isActive ? DesignTokens.Symbols.filterActive : DesignTokens.Symbols.filter
    }
}
