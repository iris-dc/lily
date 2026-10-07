import SwiftUI

/// A group: header, the actions the caller has, and the Events | Members segments (Members for members, and for every
/// signed-in caller of a public group). The view model decides what the caller may do; this draws it and hosts the
/// sheets and confirmations. Never shown for a direct conversation: `GroupDestinations` shows the person instead.
struct GroupDetailView: View {
    @State private var viewModel: GroupDetailViewModel
    @State private var section: GroupDetailSection = .events
    /// The group's upcoming games; a game created from here lands in it through `add`.
    @State private var events: EventListViewModel
    /// The group's tournaments; one created from here lands in it the same way.
    @State private var tournaments: TournamentListViewModel
    /// Built for whoever may see the roster and rebuilt when the caller's role changes, since its menus follow the role.
    @State private var members: MembersViewModel?
    @State private var presentedSheet: DetailSheet?
    @State private var confirmation: Confirmation?
    private let dependencies: AppDependencies
    @Environment(\.dismiss) private var dismiss

    private typealias Copy = AppBranding.Groups

    private enum DetailSheet: String, Identifiable {
        case invite, edit, createEvent, createTournament, signIn

        var id: String { rawValue }
    }

    /// A destructive action waiting for the caller's word.
    private enum Confirmation: Hashable, Identifiable {
        case leave, delete

        var id: Self { self }
    }

    init(viewModel: GroupDetailViewModel, dependencies: AppDependencies) {
        _viewModel = State(initialValue: viewModel)
        _events = State(initialValue: dependencies.makeEventListViewModel(scope: .group(id: viewModel.group.id)))
        _tournaments = State(initialValue: dependencies.makeTournamentListViewModel(scope: .group(id: viewModel.group.id)))
        self.dependencies = dependencies
    }

    private var group: SportGroup { viewModel.group }

    var body: some View {
        ContentScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
                    GroupHeader(group: group, distance: group.distance(from: events.userLocation)?.roadText)
                    GroupActionRow(viewModel: viewModel,
                                   onOpenChat: { dependencies.navigation.open(chat: group) },
                                   onInvite: { presentedSheet = .invite },
                                   onCreateEvent: { presentedSheet = .createEvent },
                                   onSignIn: { presentedSheet = .signIn })
                    if viewModel.access.canSeeMembers(in: group) {
                        sectionPicker
                    }
                    segment
                }
                .padding(DesignTokens.Spacing.xl)
            }
            .refreshable { await refresh() }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if viewModel.access.canChat {
                ToolbarItem(placement: .topBarTrailing) { menu }
            }
        }
        .task { viewModel.recordViewed() }
        // Re-runs when a game changes anywhere (a join on Explore, a create here), so the segment stays current.
        .task(id: dependencies.eventChanges.version) { await events.loadIfStale() }
        .task(id: dependencies.tournamentChanges.version) {
            if AppConfig.FeatureFlags.tournaments { await tournaments.loadIfStale() }
        }
        .task {
            await events.loadUserLocation()
            if AppConfig.FeatureFlags.tournaments { await tournaments.loadUserLocation() }
        }
        .onChange(of: group.role, initial: true) { rebuildMembers() }
        // Deleted, or out of a private group: there is nothing left to show here.
        .onChange(of: viewModel.isGone) {
            if viewModel.isGone { dismiss() }
        }
        .sheet(item: $presentedSheet) { sheet in
            switch sheet {
            case .invite:
                InvitePeopleSheet(viewModel: dependencies.makeInvitePeopleViewModel(for: group),
                                  errorCenter: dependencies.errorCenter)
            case .edit:
                EditGroupSheet(viewModel: dependencies.makeEditGroupViewModel(for: group, onChange: viewModel.accept),
                               errorCenter: dependencies.errorCenter)
            case .createEvent:
                // The game is hosted in this group, and lands in the segment behind the sheet at once.
                CreateEventSheet(viewModel: dependencies.makeCreateEventViewModel(onCreated: events.add, lockedGroup: group.ref),
                                 errorCenter: dependencies.errorCenter)
            case .createTournament:
                // The tournament is hosted in this group, and lands in the segment behind the sheet at once.
                CreateTournamentSheet(viewModel: dependencies.makeCreateTournamentViewModel(lockedGroup: group.ref) {
                    tournaments.add($0.tournament)
                }, errorCenter: dependencies.errorCenter)
            case .signIn:
                SignInSheet(session: dependencies.sessionController, errorCenter: dependencies.errorCenter)
            }
        }
        .confirmationDialog(confirmationTitle, isPresented: isConfirming, titleVisibility: .visible, presenting: confirmation) {
            confirmationButton(for: $0)
        }
    }

    private var sectionPicker: some View {
        Picker(Copy.title, selection: $section) {
            ForEach(GroupDetailSection.available, id: \.self) { Text($0.title).tag($0) }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier(AccessibilityIdentifiers.groupSection)
    }

    /// Events for everyone who can see the group; the roster only for those allowed it, whatever the picker says.
    @ViewBuilder private var segment: some View {
        if section == .members, let members {
            MembersList(viewModel: members)
        } else if section == .tournaments, AppConfig.FeatureFlags.tournaments {
            GroupTournamentsSegment(viewModel: tournaments)
        } else {
            GroupEventsSegment(viewModel: events)
        }
    }

    private var menu: some View {
        GroupDetailMenu(viewModel: viewModel,
                        onInvite: { presentedSheet = .invite },
                        onCreateTournament: { presentedSheet = .createTournament },
                        onEdit: { presentedSheet = .edit },
                        onLeave: { confirmation = .leave },
                        onDelete: { confirmation = .delete })
    }

    private var confirmationTitle: String {
        switch confirmation {
        case .leave: Copy.leaveConfirmation(groupName: group.name)
        case .delete: Copy.deleteConfirmation(groupName: group.name)
        case nil: ""
        }
    }

    private var isConfirming: Binding<Bool> {
        Binding(get: { confirmation != nil }, set: { if !$0 { confirmation = nil } })
    }

    private func confirmationButton(for confirmation: Confirmation) -> some View {
        Button(role: .destructive) {
            Task {
                switch confirmation {
                case .leave: await viewModel.leave()
                case .delete: await viewModel.delete()
                }
            }
        } label: {
            Text(confirmation == .leave ? Copy.leave : Copy.delete)
        }
    }

    private func rebuildMembers() {
        members = viewModel.access.canSeeMembers(in: group)
            ? dependencies.makeMembersViewModel(for: group, onChange: viewModel.accept)
            : nil
    }

    /// Pull-to-refresh reloads what the open segment shows.
    private func refresh() async {
        if section == .members, let members {
            await members.load()
        } else if section == .tournaments {
            await tournaments.load()
        } else {
            await events.load()
        }
    }
}

#Preview {
    let dependencies = AppDependencies.makeMock()
    NavigationStack {
        GroupDetailView(viewModel: dependencies.makeGroupDetailViewModel(for: MockGroupFixtures.make(now: .now)[0],
                                                                         context: .standalone,
                                                                         onChange: { _ in }),
                        dependencies: dependencies)
    }
}
