import SwiftUI

/// Toolbar button that presents the filter as a form sheet, like the create forms, full screen on the iPhone. The
/// glyph fills while any criterion is active, and every sheet session is reported to the view model as one interaction.
struct EventFilterButton: View {
    let viewModel: EventListViewModel
    @State private var isPresented = false

    private typealias Copy = AppBranding.Events.Filter

    var body: some View {
        Button {
            isPresented = true
        } label: {
            Label(Copy.title,
                  systemImage: viewModel.filter.isActive ? DesignTokens.Symbols.filterActive : DesignTokens.Symbols.filter)
        }
        .accessibilityIdentifier(AccessibilityIdentifiers.eventsFilter)
        // The filled glyph is the only visual cue that the list is narrowed; VoiceOver needs it as a value.
        .accessibilityValue(viewModel.filter.isActive ? Copy.activeValue : Copy.inactiveValue)
        .sheet(isPresented: $isPresented) {
            EventFilterSheet(viewModel: viewModel) { isPresented = false }
                .lilyFormSheet()
        }
        // One sheet session is one interaction, whether it ends with Done or a swipe down.
        .onChange(of: isPresented) { sheetPresented(isPresented) }
    }

    private func sheetPresented(_ isPresented: Bool) {
        if isPresented {
            viewModel.filterPanelOpened()
        } else {
            viewModel.filterPanelClosed()
        }
    }
}
