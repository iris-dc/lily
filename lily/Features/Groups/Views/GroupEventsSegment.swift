import SwiftUI

/// The Events segment of a group's detail: its upcoming games as cards, or why there are none. The detail owns the
/// scroll view, the refresh and the loads; this draws the list view model's state inside the detail's margins.
struct GroupEventsSegment: View {
    let viewModel: EventListViewModel

    private typealias Copy = AppBranding.Groups

    var body: some View {
        if viewModel.isInitialLoad {
            ProgressView().frame(maxWidth: .infinity)
        } else if viewModel.visibleEvents.isEmpty {
            viewModel.loadFailed ? loadFailedState : emptyState
        } else {
            EventCardList(events: viewModel.visibleEvents, distance: viewModel.distanceText, horizontalPadding: 0)
        }
    }

    private var emptyState: EmptyStateView {
        EmptyStateView(symbolName: DesignTokens.Symbols.addEvent,
                       title: Copy.eventsEmptyTitle,
                       message: Copy.eventsEmptyMessage)
    }

    private var loadFailedState: EmptyStateView {
        EmptyStateView(symbolName: DesignTokens.Symbols.error,
                       title: AppBranding.Events.loadFailedTitle,
                       message: AppBranding.Events.loadFailedMessage)
    }
}

#Preview {
    let dependencies = AppDependencies.makeMock()
    ContentScreen {
        ScrollView {
            GroupEventsSegment(viewModel: dependencies.makeEventListViewModel(scope: .group(id: MockGroupFixtures.kickersID)))
                .padding(DesignTokens.Spacing.xl)
        }
    }
}
