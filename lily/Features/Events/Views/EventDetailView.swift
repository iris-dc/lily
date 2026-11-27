import SwiftUI

/// Event detail, meetup-like: the sport, the title and the date centered on top, then the facts, the People card
/// (who hosts and who is going, each row opening the full list), what the host wrote, and the map. The join/leave
/// control sits in the pinned bottom bar with the chat and invite shortcuts, so the one thing to do is always in
/// reach. The view model decides what the control is, whose names show and whether the caller may edit; this only
/// draws it and hosts the sheets. The chat is pushed on this stack, so Back returns here.
struct EventDetailView: View {
    @State private var viewModel: EventDetailViewModel
    @State private var isEditing = false
    @State private var isInviting = false
    private let dependencies: AppDependencies

    private typealias Copy = AppBranding.People

    init(viewModel: EventDetailViewModel, dependencies: AppDependencies) {
        _viewModel = State(initialValue: viewModel)
        self.dependencies = dependencies
    }

    private var event: SportEvent { viewModel.event }

    var body: some View {
        @Bindable var viewModel = viewModel
        return ContentScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
                    DetailHeader(symbolName: event.type.symbolName,
                                 title: event.title,
                                 caption: headerCaption)
                    DetailSection(title: Copy.detailsSection) {
                        EventFactsCard(event: event)
                    }
                    peopleSection
                    aboutSection
                    EventLocationMap(event: event)
                }
                .padding(DesignTokens.Layout.detailMargin)
                .readableColumn()
            }
        }
        .navigationTitle(event.title)
        .navigationBarTitleDisplayMode(.inline)
        .hidesTabBarOnCompact()
        .safeAreaInset(edge: .bottom) { actionBar }
        .toolbar {
            if viewModel.canEdit {
                ToolbarItem(placement: .topBarTrailing) { editButton }
            }
        }
        .task {
            viewModel.recordViewed()
            await viewModel.loadParticipants()
        }
        .sheet(isPresented: $isEditing) {
            // The saved event comes back through `accept`, so this screen and the list behind it change at once.
            EditEventSheet(viewModel: dependencies.makeEditEventViewModel(for: event, onChange: viewModel.accept),
                           errorCenter: dependencies.errorCenter)
        }
        .chatDestination(item: $viewModel.openedRoom, dependencies: dependencies)
        .sheet(isPresented: $isInviting) { inviteSheet }
    }

    /// When it starts and, when known, when it ends: the line under the title.
    private var headerCaption: String {
        let start = event.startsAt.formatted(LilyTheme.DateStyles.dateTime)
        guard let untilText else { return start }
        return AppBranding.Groups.caption([start, untilText])
    }

    /// "Until 20:30" when the game ends on the start's own day, the full date otherwise; nothing without a finish.
    private var untilText: String? {
        guard let endsAt = event.endsAt else { return nil }
        let sameDay = Calendar.current.isDate(endsAt, inSameDayAs: event.startsAt)
        return AppBranding.Events.until(endsAt.formatted(sameDay ? LilyTheme.DateStyles.time : LilyTheme.DateStyles.dateTime))
    }

    /// Hosting and Going as two rows of one card: the host's circle and name, then the first avatars and the count;
    /// each opens the full list for signed-in callers (names are members-level information, so guests get the facts
    /// alone).
    private var peopleSection: some View {
        let host = Tombstone.displayName(event.hostName, deleted: event.deleted)
        return DetailSection(title: Copy.peopleSection) {
            GlassCard {
                VStack(spacing: 0) {
                    PeopleSummaryRow(title: Copy.hostingRow,
                                     names: [host],
                                     detail: host,
                                     detailMark: event.deleted == true ? Tombstone.symbol : nil,
                                     destination: peopleDestination,
                                     identifier: AccessibilityIdentifiers.peopleHostingRow)
                    Divider()
                    PeopleSummaryRow(title: Copy.goingRow,
                                     names: goingNames,
                                     detail: "\(max(event.participantCount - 1, 0))",
                                     destination: peopleDestination,
                                     identifier: AccessibilityIdentifiers.peopleGoingRow)
                }
            }
        }
    }

    private var peopleDestination: EventPeopleDestination? {
        viewModel.showsParticipants ? EventPeopleDestination(event: event) : nil
    }

    /// The first joined players for the Going stack; the host leads their own row. The count is the event's own minus
    /// the host, so it matches the pushed Going section and is right before the roster has answered.
    private var goingNames: [String] {
        viewModel.participants.filter { !$0.isHost }.map(\.displayName)
    }

    /// What the host wrote: the description and who they are looking for; nothing draws without either.
    @ViewBuilder private var aboutSection: some View {
        if event.description != nil || event.lookingFor != nil {
            DetailSection(title: Copy.aboutSection) {
                GlassCard {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                        if let description = event.description {
                            Text(description).font(.body)
                        }
                        if let lookingFor = event.lookingFor {
                            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                                Text(AppBranding.Events.lookingForTitle)
                                    .font(LilyTheme.Fonts.caption)
                                    .foregroundStyle(.secondary)
                                Text(lookingFor).font(.body)
                            }
                        }
                    }
                }
            }
        }
    }

    /// Chat and invite as quiet circles, the join/leave control as the primary; nothing mounts when the caller has
    /// nothing to do here (a guest on a started game).
    @ViewBuilder private var actionBar: some View {
        let permissions = viewModel.permissions
        if permissions.showsActionRow || viewModel.participation != .hidden {
            DetailActionBar {
                if permissions.canOpenChat {
                    Button {
                        Task { await viewModel.openChat() }
                    } label: {
                        Image(systemName: DesignTokens.Symbols.chat)
                    }
                    .lilyGlassIconButton()
                    .accessibilityLabel(AppBranding.Groups.openChat)
                    .accessibilityIdentifier(AccessibilityIdentifiers.eventActionChat)
                }
                if permissions.canInvite {
                    Button {
                        isInviting = true
                    } label: {
                        Image(systemName: DesignTokens.Symbols.invite)
                    }
                    .lilyGlassIconButton()
                    .accessibilityLabel(AppBranding.Groups.invite)
                    .accessibilityIdentifier(AccessibilityIdentifiers.eventActionInvite)
                }
            } primary: {
                participationControl
            }
        }
    }

    private var inviteSheet: some View {
        InvitePeopleSheet(viewModel: dependencies.makeEventInvitePeopleViewModel(for: event.id),
                          errorCenter: dependencies.errorCenter)
    }

    /// A plain toolbar button, like the sheets' Cancel.
    private var editButton: some View {
        Button(AppBranding.Events.Edit.action) { isEditing = true }
            .lilyToolbarTextButton()
            .accessibilityIdentifier(AccessibilityIdentifiers.eventEdit)
    }

    @ViewBuilder private var participationControl: some View {
        switch viewModel.participation {
        case .hidden:
            EmptyView()
        case .join:
            BusyButton(AppBranding.joinAction, isBusy: viewModel.isBusy) { await viewModel.join() }
                .lilyProminentButton()
        case .leave:
            BusyButton(AppBranding.leaveAction, isBusy: viewModel.isBusy) { await viewModel.leave() }
                .lilyGlassButton()
        case .full:
            BusyButton(AppBranding.eventFullAction, isBusy: viewModel.isBusy)
                .lilyProminentButton()
        case .hosting:
            DetailBarNotice(text: AppBranding.hostingNotice)
        }
    }
}

#Preview {
    let dependencies = AppDependencies.makeMock()
    NavigationStack {
        EventDetailView(viewModel: dependencies.makeEventDetailViewModel(for: MockEventFixtures.make(now: .now, count: 1)[0],
                                                                         onChange: { _ in }),
                        dependencies: dependencies)
    }
}
