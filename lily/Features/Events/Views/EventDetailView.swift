import SwiftUI

/// Event detail with the join/leave control and, for signed-in callers, who is in. The view model decides what the
/// control is, whose profiles may open and whether the caller may edit; this only draws it and hosts the edit sheet.
struct EventDetailView: View {
    @State private var viewModel: EventDetailViewModel
    @State private var isEditing = false
    private let dependencies: AppDependencies

    init(viewModel: EventDetailViewModel, dependencies: AppDependencies) {
        _viewModel = State(initialValue: viewModel)
        self.dependencies = dependencies
    }

    private var event: SportEvent { viewModel.event }

    var body: some View {
        ContentScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
                    EventTypeChip(type: event.type)
                    OwnerTitleBlock(title: event.title,
                                    subtitle: AppBranding.hostedByTitle(for: event.hostName),
                                    destination: viewModel.hostProfile,
                                    identifier: AccessibilityIdentifiers.eventHost)
                    if let group = event.group {
                        HostedInLine(group: group)
                    }
                    if let description = event.description {
                        Text(description).font(.body)
                    }
                    EventFactsCard(event: event)
                    if viewModel.showsParticipants {
                        participantsSection
                    }
                    if let lookingFor = event.lookingFor {
                        lookingForCard(lookingFor)
                    }
                    participationControl
                }
                .padding(DesignTokens.Layout.detailMargin)
                .readableColumn()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
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
    }

    /// A plain toolbar button, like the sheets' Cancel: `.borderless` collapses to an icon-sized circle in an iOS 26 bar.
    private var editButton: some View {
        Button(AppBranding.Events.Edit.action) { isEditing = true }
            .accessibilityIdentifier(AccessibilityIdentifiers.eventEdit)
    }

    /// "Who's in": the host first, then everyone else, each row opening the person's profile except the caller's own.
    private var participantsSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text(AppBranding.Events.participantsTitle)
                .font(LilyTheme.Fonts.cardTitle)
            if viewModel.isLoadingParticipants, viewModel.participants.isEmpty {
                ProgressView().frame(maxWidth: .infinity)
            }
            ForEach(viewModel.participants) { participant in
                ParticipantRow(participant: participant, isSelf: viewModel.isSelf(participant))
            }
        }
    }

    private func lookingForCard(_ text: String) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                Label(AppBranding.Events.lookingForTitle, systemImage: DesignTokens.Symbols.lookingFor)
                    .labelStyle(.iconColumn)
                    .font(LilyTheme.Fonts.caption)
                    .foregroundStyle(.secondary)
                Text(text).font(.body)
            }
        }
    }

    @ViewBuilder
    private var participationControl: some View {
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
            Text(AppBranding.hostingNotice)
                .font(LilyTheme.Fonts.caption)
                .foregroundStyle(.secondary)
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
