import SwiftUI

/// Another person: their mark and name, "Message" for anyone but the caller, what they wrote about themselves, and what
/// the two share: groups, games and tournaments. The view model decides what the caller may do; this draws it.
struct UserProfileView: View {
    @State private var viewModel: UserProfileViewModel
    let dependencies: AppDependencies

    private typealias Copy = AppBranding.People

    init(viewModel: UserProfileViewModel, dependencies: AppDependencies) {
        _viewModel = State(initialValue: viewModel)
        self.dependencies = dependencies
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        return ContentScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
                    header
                    content
                }
                .padding(.vertical, DesignTokens.Spacing.xl)
                .readableColumn()
            }
        }
        .navigationTitle(viewModel.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .hidesTabBarOnCompact()
        .safeAreaInset(edge: .bottom) {
            if viewModel.canMessage {
                DetailActionBar {
                    EmptyView()
                } primary: {
                    messageButton
                }
            }
        }
        .chatDestination(item: $viewModel.openedConversation, dependencies: dependencies)
        .task { await viewModel.load() }
    }

    private var header: some View {
        HStack(spacing: DesignTokens.Spacing.lg) {
            AvatarCircle(initials: viewModel.displayName.initials)
            ScreenTitle(text: viewModel.displayName)
        }
        .padding(.horizontal, DesignTokens.Layout.screenMargin)
    }

    /// Opens (or reopens) the direct conversation from the pinned bar, like a detail's primary action; no spinner,
    /// only the second tap is guarded.
    private var messageButton: some View {
        BusyButton(
            isBusy: viewModel.isStartingConversation,
            showsSpinner: false,
            action: { await viewModel.message() },
            label: { Label(Copy.message, systemImage: DesignTokens.Symbols.chat) }
        )
        .lilyProminentButton()
        .accessibilityIdentifier(AccessibilityIdentifiers.profileMessage)
    }

    /// The bio and what the two share, once the profile answered: one spinner, or one retry, for all of it.
    @ViewBuilder private var content: some View {
        switch viewModel.state {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignTokens.Spacing.lg)
        case .failed:
            loadFailed
        case .loaded(let profile):
            loaded(profile)
        }
    }

    @ViewBuilder private func loaded(_ profile: UserProfile) -> some View {
        if let bio = profile.bio {
            Text(bio)
                .font(.body)
                .padding(.horizontal, DesignTokens.Layout.screenMargin)
                .accessibilityIdentifier(AccessibilityIdentifiers.profileBio)
        }
        RowsSection(title: Copy.sharedGroupsTitle, emptyNote: Copy.noSharedGroups, items: profile.sharedGroups) {
            SharedGroupRow(group: $0)
        }
        RowsSection(title: Copy.sharedEventsTitle, emptyNote: Copy.noSharedEvents, items: profile.sharedEvents) {
            SharedEventRow(event: $0)
        }
        RowsSection(title: Copy.sharedTournamentsTitle,
                    emptyNote: Copy.noSharedTournaments,
                    items: profile.sharedTournaments) {
            SharedTournamentRow(tournament: $0)
        }
    }

    /// The popup said what went wrong; the screen offers the retry.
    private var loadFailed: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            SectionNote(text: Copy.loadFailedTitle)
            Button(AppBranding.Groups.tryAgain) { Task { await viewModel.load() } }
                .lilyGlassButton(sizing: .fitted, controlSize: .regular, labelColor: .lilyInk)
                .padding(.horizontal, DesignTokens.Layout.screenMargin)
        }
    }
}

#Preview {
    let dependencies = AppDependencies.makeMock()
    let marta = UserProfileDestination(userId: MockGroupFixtures.memberID(for: "Marta"), displayName: "Marta")
    NavigationStack {
        UserProfileView(viewModel: dependencies.makeUserProfileViewModel(for: marta), dependencies: dependencies)
    }
}
