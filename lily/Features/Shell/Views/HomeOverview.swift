import SwiftUI

/// The signed-in Home content: a segmented picker (Events | Tournaments | Groups) under the title showing one of the
/// caller's lists at a time, a prominent full-width create button at the top of every segment seeding the wizard with
/// the segment's kind, a subtle count line over the list, and pull-to-refresh reloading the visible segment alone. An
/// empty segment keeps the create button and shows a friendly hint.
struct HomeOverview: View {
    let groups: MyGroupsStore
    let events: EventListViewModel
    let tournaments: TournamentListViewModel
    let dependencies: AppDependencies
    /// The create button's choice, handed up so the screen decides how the wizard is presented.
    let onCreate: (CreationKind) -> Void
    @State private var segment: HomeSegment = .events
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.motion) private var motion

    private typealias Copy = AppBranding.Home

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                picker
                createButton
                segmentContent
            }
            .padding(.top, DesignTokens.Spacing.sm)
            .padding(.bottom, DesignTokens.Spacing.xxl)
            // A segment switch is not the user's own drag, so the move is judged by the motion preference.
            .animation(motion.allowsMovement ? .snappy(duration: DesignTokens.Duration.fast) : nil, value: segment)
        }
        .refreshable { await refreshVisible() }
    }

    private var picker: some View {
        Picker(Copy.segmentPicker, selection: $segment) {
            ForEach(HomeSegment.offered(), id: \.self) { segment in
                Text(segment.title).tag(segment)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier(AccessibilityIdentifiers.homeSegment)
        .padding(.horizontal, DesignTokens.Layout.screenMargin)
        .readableColumn()
    }

    /// The label reads as ink and the accent stays on the plus, the mark beside it, as everywhere below headline size.
    private var createButton: some View {
        Button {
            onCreate(segment.creationKind)
        } label: {
            Label {
                Text(segment.createTitle)
            } icon: {
                Image(systemName: DesignTokens.Symbols.create)
                    .foregroundStyle(Color.lilyAccent)
            }
        }
        .lilyGlassButton(labelColor: .lilyInk)
        .accessibilityIdentifier(AccessibilityIdentifiers.homeCreate)
        .padding(.horizontal, DesignTokens.Layout.screenMargin)
        .readableColumn()
    }

    @ViewBuilder private var segmentContent: some View {
        switch segment {
        case .events:
            slot(state: events.listState, count: events.visibleEvents.count) {
                EventCardList(events: events.visibleEvents, distance: events.distanceText)
            }
        case .tournaments:
            slot(state: tournaments.listState, count: tournaments.visibleTournaments.count) {
                TournamentCardList(tournaments: tournaments.visibleTournaments, distance: tournaments.distanceText)
            }
        case .groups:
            slot(state: groups.listState, count: groups.communities.count) {
                groupsList
            }
        }
    }

    /// A row (a tile in the regular-width grid) opens the group's detail, the place to manage a membership.
    @ViewBuilder private var groupsList: some View {
        if sizeClass == .regular {
            GroupTileGrid(groups: groups.communities, distance: groupDistance)
        } else {
            GroupRowList(groups: groups.communities) { dependencies.navigation.open(group: $0) }
        }
    }

    /// The tiles take the position the events list loads (`HomeView.loadIfStale` asks for it).
    private func groupDistance(_ group: SportGroup) -> String? {
        group.distance(from: events.userLocation)?.roadText()
    }

    /// One segment's pane under the create button: the list with its count line, or the segment's own state.
    @ViewBuilder
    private func slot(state: ListState, count: Int, @ViewBuilder content: () -> some View) -> some View {
        switch state {
        case .content:
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                Text(segment.countLine(count))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, DesignTokens.Layout.screenMargin)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .readableColumn()
                content()
            }
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignTokens.Spacing.xxl)
        case .failed:
            note(segment.failedMessage)
        case .empty:
            EmptyStateView(symbolName: segment.symbolName, title: segment.emptyTitle, message: segment.emptyMessage)
                .readableColumn()
                .padding(.top, DesignTokens.Spacing.xl)
        }
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.horizontal, DesignTokens.Layout.screenMargin)
            .padding(.top, DesignTokens.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .readableColumn()
    }

    /// Pull-to-refresh reloads the visible segment alone.
    private func refreshVisible() async {
        switch segment {
        case .events: await events.load()
        case .tournaments: await tournaments.load()
        case .groups: await groups.reload()
        }
    }
}

#Preview {
    let dependencies = AppDependencies.makeMock()
    NavigationStack {
        ContentScreen {
            HomeOverview(groups: dependencies.myGroups,
                         events: dependencies.lists.homeEvents,
                         tournaments: dependencies.lists.homeTournaments,
                         dependencies: dependencies,
                         onCreate: { _ in })
        }
    }
}
