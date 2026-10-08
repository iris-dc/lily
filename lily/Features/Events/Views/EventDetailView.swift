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
                    titleBlock
                    if let group = event.group {
                        groupLine(group)
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
                .padding(DesignTokens.Spacing.xl)
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

    /// The title with "Hosted by <name>" under it, a link to the host's profile when the caller may open it.
    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            ScreenTitle(text: event.title)
            if let host = viewModel.hostProfile {
                NavigationLink(value: host) {
                    HStack(spacing: DesignTokens.Spacing.xs) {
                        ScreenSubtitle(text: AppBranding.hostedByTitle(for: event.hostName))
                        Image(systemName: DesignTokens.Symbols.chevron)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(AccessibilityIdentifiers.eventHost)
            } else {
                ScreenSubtitle(text: AppBranding.hostedByTitle(for: event.hostName))
            }
        }
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

    /// "Hosted in <group>": a link to the group when it is public and live, its name alone otherwise; a private
    /// group's game says so, since the link is withheld on purpose.
    private func groupLine(_ group: EventGroupRef) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            if group.isLinkable {
                NavigationLink(value: group) {
                    Label(AppBranding.Groups.hostedIn(groupName: group.name), systemImage: DesignTokens.Symbols.groups)
                        .foregroundStyle(Color.lilyAccent)
                }
                .buttonStyle(.plain)
            } else {
                Label(AppBranding.Groups.hostedIn(groupName: group.name), systemImage: DesignTokens.Symbols.groups)
                    .foregroundStyle(.secondary)
            }
            if group.isPrivate {
                Text(AppBranding.Groups.membersOnly)
                    .font(LilyTheme.Fonts.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .font(.subheadline)
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
            actionButton(AppBranding.joinAction) { await viewModel.join() }
                .lilyProminentButton()
        case .leave:
            actionButton(AppBranding.leaveAction) { await viewModel.leave() }
                .lilyGlassButton()
        case .full:
            actionButton(AppBranding.eventFullAction)
                .lilyProminentButton()
        case .hosting:
            Text(AppBranding.hostingNotice)
                .font(LilyTheme.Fonts.caption)
                .foregroundStyle(.secondary)
        }
    }

    /// Action with a spinner beside its title while the request runs. Without an action it is disabled. The caller
    /// applies the button style, which also sets the full width and height (see the Buttons note in CLAUDE.md).
    private func actionButton(_ title: String, action: (() async -> Void)? = nil) -> some View {
        Button {
            Task { await action?() }
        } label: {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Text(title)
                if viewModel.isBusy {
                    // The button's `.large` control size would inflate the spinner past the text height.
                    ProgressView()
                        .controlSize(.regular)
                        .accessibilityHidden(true)
                }
            }
        }
        .disabled(action == nil || viewModel.isBusy)
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
