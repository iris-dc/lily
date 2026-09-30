import SwiftUI

/// Another person: their mark and name, "Message" for anyone but the caller, and the groups the two share. The view
/// model decides what the caller may do; this draws it.
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
                    sharedGroups
                }
                .padding(.vertical, DesignTokens.Spacing.xl)
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
        Button {
            Task { await viewModel.message() }
        } label: {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Label(Copy.message, systemImage: DesignTokens.Symbols.chat)
                if viewModel.isStartingConversation {
                    ProgressView()
                        .controlSize(.regular)
                        .accessibilityHidden(true)
                }
            }
        }
        .lilyProminentButton()
        .disabled(viewModel.isStartingConversation)
        .accessibilityIdentifier(AccessibilityIdentifiers.profileMessage)
        .padding(.horizontal, DesignTokens.Layout.screenMargin)
    }

    private var sharedGroups: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            SectionTitle(text: Copy.sharedGroupsTitle)
            sharedGroupsContent
        }
    }

    @ViewBuilder private var sharedGroupsContent: some View {
        switch viewModel.state {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignTokens.Spacing.lg)
        case .failed:
            loadFailed
        case .loaded(let profile) where profile.sharedGroups.isEmpty:
            note(Copy.noSharedGroups)
        case .loaded(let profile):
            rows(profile.sharedGroups)
        }
    }

    private func rows(_ groups: [GroupSummary]) -> some View {
        LazyVStack(spacing: 0) {
            ForEach(groups) { group in
                SharedGroupRow(group: group)
                AvatarRowDivider()
            }
        }
        .padding(.horizontal, DesignTokens.Layout.screenMargin)
        // A container, not a stamp on every row: the rows keep their `group-row-<id>` identifiers.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityIdentifiers.profileSharedGroups)
    }

    /// The popup said what went wrong; the section offers the retry.
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
