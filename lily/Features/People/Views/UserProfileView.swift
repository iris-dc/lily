import SwiftUI

/// Another person: their mark and name, "Message" for anyone but the caller, what they wrote about themselves, and what
/// the two share: groups, games and tournaments. The view model decides what the caller may do; this draws it.
struct UserProfileView: View {
    @State private var viewModel: UserProfileViewModel

    private typealias Copy = AppBranding.People

    init(viewModel: UserProfileViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ContentScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
                    header
                    if viewModel.canMessage {
                        messageButton
                    }
                    content
                }
                .padding(.vertical, DesignTokens.Spacing.xl)
                .readableColumn()
            }
        }
        .navigationTitle(viewModel.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
    }

    private var header: some View {
        HStack(spacing: DesignTokens.Spacing.lg) {
            AvatarCircle(initials: viewModel.displayName.initials)
            ScreenTitle(text: viewModel.displayName)
        }
        .padding(.horizontal, DesignTokens.Layout.screenMargin)
    }

    /// Opens (or reopens) the direct conversation; a spinner beside the title while the request runs.
    private var messageButton: some View {
        BusyButton(
            isBusy: viewModel.isStartingConversation,
            action: { await viewModel.message() },
            label: { Label(Copy.message, systemImage: DesignTokens.Symbols.chat) }
        )
        .lilyProminentButton()
        .accessibilityIdentifier(AccessibilityIdentifiers.profileMessage)
        .padding(.horizontal, DesignTokens.Layout.screenMargin)
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
        section(Copy.sharedGroupsTitle, orElse: Copy.noSharedGroups, profile.sharedGroups) { SharedGroupRow(group: $0) }
        section(Copy.sharedEventsTitle, orElse: Copy.noSharedEvents, profile.sharedEvents) { SharedEventRow(event: $0) }
        section(Copy.sharedTournamentsTitle, orElse: Copy.noSharedTournaments, profile.sharedTournaments) {
            SharedTournamentRow(tournament: $0)
        }
    }

    /// A title over the rows, or over a line saying there are none yet.
    private func section<Item: Identifiable, Row: View>(
        _ title: String,
        orElse empty: String,
        _ items: [Item],
        @ViewBuilder row: @escaping (Item) -> Row
    ) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            SectionTitle(text: title)
            if items.isEmpty {
                note(empty)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(items) { item in
                        row(item)
                        AvatarRowDivider()
                    }
                }
                .padding(.horizontal, DesignTokens.Layout.screenMargin)
            }
        }
    }

    /// The popup said what went wrong; the screen offers the retry.
    private var loadFailed: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            note(Copy.loadFailedTitle)
            Button(AppBranding.Groups.tryAgain) { Task { await viewModel.load() } }
                .lilyGlassButton(sizing: .fitted, controlSize: .regular, labelColor: .lilyInk)
                .padding(.horizontal, DesignTokens.Layout.screenMargin)
        }
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.horizontal, DesignTokens.Layout.screenMargin)
    }
}

#Preview {
    let dependencies = AppDependencies.makeMock()
    let marta = UserProfileDestination(userId: MockGroupFixtures.memberID(for: "Marta"), displayName: "Marta")
    NavigationStack {
        UserProfileView(viewModel: dependencies.makeUserProfileViewModel(for: marta))
    }
}
