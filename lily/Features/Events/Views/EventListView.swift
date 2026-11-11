import SwiftUI

/// The Explore screen: the upcoming games as a list, switchable to a map, narrowed through the filter sheet the
/// toolbar opens, with the "+" floating over the content (its menu names the kind; a signed-in user gets the wizard
/// seeded with it, a guest the sign-in sheet) and a header (the carousels) above the list. On a wide window
/// (`LayoutMode.wide`) the map is not a mode but a pane: the content column on the left, the map always on the right,
/// and the picker gone (`EventListLayout`).
struct EventListView<Header: View>: View {
    /// Heading over the cards, for a screen whose header (the groups carousel) would otherwise make them read as its.
    let listTitle: String?
    /// The upcoming list, owned by `ShellLists` for the app's lifetime, so it holds content before this screen exists.
    let viewModel: EventListViewModel
    let dependencies: AppDependencies
    let header: () -> Header
    /// Pull-to-refresh reloads the header's content too (the carousel), before the events.
    let refreshHeader: () async -> Void
    @State var presentation: EventsPresentation = .list
    @State var presentedSheet: ExploreSheet?
    /// The wizard behind `presentedSheet`'s wizard case, made once per presentation in `present(_:)` and owned above
    /// both presenters, so a mid-flow width-class change re-hosts the same flow instead of destroying it.
    @State var wizardModel: AppCreationWizardModel?
    /// The header's measured height: a spinner or empty state is centred in what the screen leaves under it.
    @State var headerHeight: CGFloat = 0
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.layoutMode) private var layoutMode

    private var layout: EventListLayout { .resolve(mode: layoutMode) }
    /// Whether the map is the whole content right now: the switchable layout with the picker on "Map".
    var showsMapAlone: Bool { layout == .switchable && presentation == .map }

    /// Whether the wizard is up and rides the full-screen cover: only on a compact width; any other width keeps it a
    /// sheet, sized like every form.
    private var presentsWizardAsCover: Bool {
        guard case .wizard = presentedSheet else { return false }
        return layoutMode == .compact
    }

    /// The two presenters split `presentedSheet` between them: each shows it only while the other does not claim it.
    private var sheetItem: Binding<ExploreSheet?> {
        Binding(get: { presentsWizardAsCover ? nil : presentedSheet }, set: { presentedSheet = $0 })
    }

    private var wizardCoverItem: Binding<ExploreSheet?> {
        Binding(get: { presentsWizardAsCover ? presentedSheet : nil }, set: { presentedSheet = $0 })
    }

    init(listTitle: String?,
         viewModel: EventListViewModel,
         dependencies: AppDependencies,
         refreshHeader: @escaping () async -> Void,
         @ViewBuilder header: @escaping () -> Header) {
        self.listTitle = listTitle
        self.viewModel = viewModel
        self.dependencies = dependencies
        self.header = header
        self.refreshHeader = refreshHeader
    }

    var body: some View {
        NavigationStack {
            ContentScreen {
                screen
            }
            .navigationTitle(AppBranding.exploreTitle)
            .navigationBarTitleDisplayMode(showsMapAlone ? .inline : .large)
            .navigationDestination(for: SportEvent.self) { event in
                // A join or leave on the detail comes back through `replace`, so this list is right on return.
                EventDetailView(viewModel: dependencies.makeEventDetailViewModel(for: event, onChange: viewModel.replace),
                                dependencies: dependencies)
            }
            // An event's "Hosted in" link and the carousel push groups here, so every stack knows the group screens.
            .groupDestinations(dependencies: dependencies)
            .toolbar {
                ProfileCornerButton(dependencies: dependencies)
                ToolbarItem(placement: .topBarTrailing) { EventFilterButton(viewModel: viewModel) }
                if layout == .switchable {
                    // iOS 26 gives every toolbar item its own glass; the segmented picker already draws one.
                    ToolbarItem(placement: .topBarTrailing) { presentationPicker }
                        .sharedBackgroundVisibility(.hidden)
                }
            }
        }
        // Re-runs when a game changes anywhere (a create from a group's detail pushed on this stack), so the list behind
        // the detail is right on return, not only on the next appearance.
        .task(id: dependencies.eventChanges.version) { await viewModel.loadIfStaleNearTheUser() }
        .onChange(of: presentation) { viewModel.presentationChanged(to: presentation) }
        // Coming back to the foreground is the one moment location permission may have changed (Settings), and the
        // user may have moved meanwhile, so the position is asked for again; the cache answers within its TTL.
        .onChange(of: scenePhase) {
            if scenePhase == .active { Task { await viewModel.refreshUserLocation() } }
        }
        // A shortcut's create waits on the navigation until Explore is on screen; `initial` catches one that arrived
        // while another tab was showing.
        .onChange(of: dependencies.navigation.pendingCreate, initial: true) { consumePendingCreate() }
        .sheet(item: sheetItem, onDismiss: clearWizardAfterDismiss) { sheet in sheetContent(for: sheet) }
        // The wizard rides a full-screen cover on a compact width and a form sheet elsewhere; both presenters share
        // `presentedSheet`, so a width-class change mid-flow re-hosts the wizard rather than losing the draft.
        .fullScreenCover(item: wizardCoverItem, onDismiss: clearWizardAfterDismiss) { _ in wizardContent }
    }

    /// One column with the list or the map, or, side by side, the content column (with the "+" over its corner) and
    /// the map pane taking the rest of the width.
    @ViewBuilder
    private var screen: some View {
        switch layout {
        case .switchable:
            withCreateButton(content)
        case .sideBySide:
            HStack(spacing: 0) {
                withCreateButton(listContent)
                    .containerRelativeFrame(.horizontal) { length, _ in length * DesignTokens.Layout.exploreContentFraction }
                mapPane
            }
        }
    }

    /// The button floats inside the safe area, so it sits above the floating tab bar rather than under it; the corner
    /// paddings carry the fourth design round's down-left nudge.
    private func withCreateButton(_ content: some View) -> some View {
        ZStack(alignment: .bottomTrailing) {
            content
            CreateButton { kind in presentForUser(.wizard(CreationSeed(kind: kind))) }
                .padding(.trailing, DesignTokens.Layout.floatingButtonTrailingPadding)
                .padding(.bottom, DesignTokens.Layout.floatingButtonBottomPadding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// The map beside the content column: always there, nothing floating over it, its selected card at its own bottom.
    private var mapPane: some View {
        EventsMapView(viewModel: viewModel)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(AccessibilityIdentifiers.exploreMapPane)
    }
}
