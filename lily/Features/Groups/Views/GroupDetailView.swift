import SwiftUI

/// A group: its mark, name and size centered on top, where it plays, the People card (who runs it and who is in, each
/// row opening the roster), the description, and the Events | Tournaments segments the caller's access allows
/// (`GroupDetailSection.available`). Join or Open chat sits in the pinned bottom bar with the invite and create-event
/// shortcuts. The view model decides what the caller may do; this draws it and hosts the sheets and confirmations
/// (the roster's own questions moved with it to `GroupMembersView`). Never shown for a direct conversation:
/// `GroupDestinations` shows the person instead.
struct GroupDetailView: View {
    @State var viewModel: GroupDetailViewModel
    @State private var section: GroupDetailSection = .events
    /// The group's upcoming games; a game created from here lands in it through `add`.
    @State var events: EventListViewModel
    /// The group's tournaments; one created from here lands in it the same way.
    @State var tournaments: TournamentListViewModel
    /// Built for whoever may see the roster and rebuilt when the caller's access changes (a role, a sign-in), since
    /// its menus follow it; a change to the group itself reaches it through `update(group:)`. The People card reads
    /// its first names, the pushed members screen the rest.
    @State var members: MembersViewModel?
    @State var presentedSheet: DetailSheet?
    /// The wizard behind the two create cases, made once per presentation in `presentWizard(_:kind:)` and owned
    /// above both presenters, so a mid-flow width-class change re-hosts the same flow (`GroupDetailView+Create`).
    @State var wizardModel: AppCreationWizardModel?
    @State private var confirmation: GroupConfirmation?
    let dependencies: AppDependencies
    @Environment(\.dismiss) private var dismiss
    @Environment(\.layoutMode) var layoutMode

    typealias Copy = AppBranding.Groups

    enum DetailSheet: String, Identifiable {
        case invite, edit, createEvent, createTournament, signIn, report

        var id: String { rawValue }

        /// The two cases the creation wizard hosts, seeded with the kind and this group locked.
        var isWizard: Bool { self == .createEvent || self == .createTournament }
    }

    /// Where Mine stands: a reload bumps `loads`, a sibling's write `changes`; either moves the detail's refresh.
    private struct StoreKey: Hashable {
        let changes: Int
        let loads: Int
    }

    init(viewModel: GroupDetailViewModel, dependencies: AppDependencies) {
        _viewModel = State(initialValue: viewModel)
        _events = State(initialValue: dependencies.makeEventListViewModel(scope: .group(id: viewModel.group.id)))
        _tournaments = State(initialValue: dependencies.makeTournamentListViewModel(scope: .group(id: viewModel.group.id)))
        self.dependencies = dependencies
    }

    var group: SportGroup { viewModel.group }
    /// What the picker offers this caller; one segment alone needs no picker.
    private var sections: [GroupDetailSection] { GroupDetailSection.available(for: viewModel.access, in: group) }

    var body: some View {
        ContentScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
                    header
                    detailsSection
                    peopleSection
                    aboutSection
                    if sections.count > 1 {
                        sectionPicker
                    }
                    segment
                }
                .padding(DesignTokens.Layout.detailMargin)
                .readableColumn()
            }
            .refreshable { await refresh() }
        }
        .navigationTitle(group.name)
        .navigationBarTitleDisplayMode(.inline)
        .hidesTabBarOnCompact()
        .safeAreaInset(edge: .bottom) { actionBar }
        // This detail's roster rides its own view model, so a change made there reaches the People card and the
        // header count at once; another group's push (two details on one stack) builds a fresh one from the value.
        .navigationDestination(for: GroupMembersDestination.self) { destination in
            if destination.group.id == group.id, let members {
                GroupMembersView(viewModel: members)
            } else {
                GroupMembersView(viewModel: dependencies.makeMembersViewModel(for: destination.group) { _ in
                    dependencies.groupChanges.recordChange()
                })
            }
        }
        .chatDestination(item: $viewModel.openedChat, dependencies: dependencies)
        .toolbar {
            if viewModel.showsMenu {
                ToolbarItem(placement: .topBarTrailing) { menu }
            }
        }
        .task { viewModel.recordViewed() }
        // Re-runs when a game changes anywhere (a join on Explore, a create here), so the segment stays current.
        .task(id: dependencies.eventChanges.version) { await events.loadIfStale() }
        // A Mine reload or a sibling's write under the open detail: the header and the actions follow the fresh group.
        .task(id: StoreKey(changes: dependencies.groupChanges.version, loads: dependencies.myGroups.loadVersion)) {
            viewModel.refreshFromStore()
        }
        .task(id: dependencies.tournamentChanges.version) {
            if AppConfig.FeatureFlags.tournaments { await tournaments.loadIfStale() }
        }
        .task {
            await events.loadUserLocation()
            if AppConfig.FeatureFlags.tournaments { await tournaments.loadUserLocation() }
        }
        // The People card's stack needs the first names, so the roster loads with the detail, not with a segment.
        .task(id: members.map(ObjectIdentifier.init)) { await members?.load() }
        .onChange(of: viewModel.access, initial: true) { rebuildMembers() }
        .onChange(of: viewModel.group) { _, group in members?.update(group: group) }
        // A segment that disappears (a sign-out while on Tournaments) must not leave the picker without a selection.
        .onChange(of: sections) { _, sections in
            if !sections.contains(section) { section = .events }
        }
        // Deleted, or out of a private group: there is nothing left to show here.
        .onChange(of: viewModel.isGone) {
            if viewModel.isGone { dismiss() }
        }
        .sheet(item: sheetItem, onDismiss: clearWizardAfterDismiss) { sheet in
            switch sheet {
            case .invite:
                InvitePeopleSheet(viewModel: dependencies.makeInvitePeopleViewModel(for: group),
                                  errorCenter: dependencies.errorCenter)
            case .edit:
                EditGroupSheet(viewModel: dependencies.makeEditGroupViewModel(for: group, onChange: viewModel.accept),
                               errorCenter: dependencies.errorCenter)
            case .createEvent, .createTournament:
                // The wizard, seeded with the kind and this group locked (the flow opens on its first step); on a
                // regular width it is this form sheet, on compact the full-screen cover below claims it. The grabber
                // is hidden because the wizard's dirty-draft lock is not transient.
                wizardContent.lilyFormSheet()
                    .presentationDragIndicator(.hidden)
            case .signIn:
                SignInSheet(session: dependencies.sessionController,
                            errorCenter: dependencies.errorCenter,
                            language: dependencies.language.language)
            case .report:
                ReportSheet(viewModel: dependencies.makeReportViewModel(for: viewModel.reportTarget, title: Copy.reportGroup),
                            errorCenter: dependencies.errorCenter)
            }
        }
        // The wizard rides a full-screen cover on a compact width; both presenters share `presentedSheet`, so a
        // width-class change mid-flow re-hosts the flow rather than losing the draft (`GroupDetailView+Create`).
        .fullScreenCover(item: wizardCoverItem, onDismiss: clearWizardAfterDismiss) { _ in wizardContent }
        .confirmationDialog(item: $confirmation,
                            title: { $0.title(groupName: group.name) },
                            actions: { confirmationButton(for: $0) })
    }

    private var sectionPicker: some View {
        Picker(Copy.title, selection: $section) {
            ForEach(sections, id: \.self) { Text($0.title).tag($0) }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier(AccessibilityIdentifiers.groupSection)
    }

    /// Which segment is on screen: tournaments only for those offered them, whatever the picker says; events for
    /// everyone who can see the group.
    private var shownSection: GroupDetailSection {
        section == .tournaments && sections.contains(.tournaments) ? .tournaments : .events
    }

    @ViewBuilder private var segment: some View {
        switch shownSection {
        case .tournaments: GroupTournamentsSegment(viewModel: tournaments)
        case .events: GroupEventsSegment(viewModel: events)
        }
    }

    private var menu: some View {
        GroupDetailMenu(viewModel: viewModel,
                        onInvite: { presentedSheet = .invite },
                        onCreateTournament: { presentCreateTournament() },
                        onEdit: { presentedSheet = .edit },
                        onLeave: { confirmation = .leave },
                        onReport: { presentedSheet = .report },
                        onDelete: { confirmation = .delete })
    }

    private func confirmationButton(for confirmation: GroupConfirmation) -> some View {
        Button(role: .destructive) {
            Task { await run(confirmation) }
        } label: {
            Text(confirmation.buttonTitle)
        }
    }

    /// Leaving and deleting are the detail's; the roster's removals moved to `GroupMembersView` with its list.
    private func run(_ confirmation: GroupConfirmation) async {
        switch confirmation {
        case .leave: await viewModel.leave()
        case .delete: await viewModel.delete()
        case .remove(let member): await members?.perform(.remove, on: member)
        case .ban(let member): await members?.perform(.ban, on: member)
        }
    }

    private func rebuildMembers() {
        members = viewModel.showsRoster
            ? dependencies.makeMembersViewModel(for: group, onChange: viewModel.accept)
            : nil
    }

    /// Pull-to-refresh reloads what the open segment shows, and the roster behind the People card.
    private func refresh() async {
        switch shownSection {
        case .tournaments: await tournaments.load()
        case .events: await events.load()
        }
        await members?.load()
    }
}

#Preview {
    let dependencies = AppDependencies.makeMock()
    NavigationStack {
        GroupDetailView(viewModel: dependencies.makeGroupDetailViewModel(for: MockGroupFixtures.make(now: .now)[0],
                                                                         context: .standalone),
                        dependencies: dependencies)
    }
}
