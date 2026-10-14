import SwiftUI

/// Toolbar button that drops the filter panel down from itself as a popover. The glyph fills while any criterion is
/// active, and every panel session is reported to the view model as one interaction.
struct EventFilterButton: View {
    let viewModel: EventListViewModel

    private typealias Copy = AppBranding.Events.Filter

    var body: some View {
        FilterDropdownButton(title: Copy.title,
                             isActive: viewModel.filter.isActive,
                             identifier: AccessibilityIdentifiers.eventsFilter,
                             onPresentedChange: panelPresented) { dismiss in
            EventFilterPanel(viewModel: viewModel, onDone: dismiss)
        }
    }

    /// One panel session is one interaction, whether it ends with Done or a tap outside.
    private func panelPresented(_ isPresented: Bool) {
        if isPresented {
            viewModel.filterPanelOpened()
        } else {
            viewModel.filterPanelClosed()
        }
    }
}
