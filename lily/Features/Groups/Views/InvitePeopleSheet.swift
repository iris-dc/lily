import SwiftUI

/// Invite people the caller shares a group or a game with into a group; the invitee answers from their inbox. A name
/// search over the candidates, one row per person with an Invite button that reads "Invited" once sent, and the
/// states around the list. Mounts its own popup, since a sheet is drawn above the root's.
struct InvitePeopleSheet: View {
    @State private var viewModel: InvitePeopleViewModel
    private let errorCenter: ErrorCenter
    @Environment(\.dismiss) private var dismiss

    private typealias Copy = AppBranding.Groups.Invite

    init(viewModel: InvitePeopleViewModel, errorCenter: ErrorCenter) {
        _viewModel = State(initialValue: viewModel)
        self.errorCenter = errorCenter
    }

    var body: some View {
        NavigationStack {
            ContentScreen {
                VStack(spacing: 0) {
                    if viewModel.showsSearch {
                        searchField
                    }
                    content
                }
            }
            .navigationTitle(Copy.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button(Copy.done) { dismiss() } }
            }
            .tint(Color.lilyAccent)
            .task { await viewModel.load() }
        }
        .errorPopup(errorCenter)
        .presentationDragIndicator(.visible)
    }

    private var searchField: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: DesignTokens.Symbols.search)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            TextField(Copy.searchPrompt, text: $viewModel.query)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .accessibilityIdentifier(AccessibilityIdentifiers.inviteSearch)
        }
        .lilyField()
        .padding(.horizontal, DesignTokens.Layout.screenMargin)
        .padding(.vertical, DesignTokens.Spacing.md)
    }

    @ViewBuilder private var content: some View {
        switch viewModel.content {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed:
            EmptyStateView(symbolName: DesignTokens.Symbols.error,
                           title: Copy.loadFailedTitle,
                           message: AppBranding.Groups.loadFailedMessage,
                           actionTitle: AppBranding.Groups.tryAgain) {
                Task { await viewModel.load() }
            }
        case .nobody:
            EmptyStateView(symbolName: DesignTokens.Symbols.invite, title: Copy.emptyTitle, message: Copy.emptyMessage)
        case .noMatches:
            EmptyStateView(symbolName: DesignTokens.Symbols.search, title: Copy.noMatchesTitle, message: Copy.noMatchesMessage)
        case .people:
            people
        }
    }

    private var people: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.visible) { candidate in
                    InviteCandidateRow(candidate: candidate, isSending: viewModel.isSending(candidate)) {
                        Task { await viewModel.invite(candidate) }
                    }
                    AvatarRowDivider()
                }
            }
            .padding(.horizontal, DesignTokens.Layout.screenMargin)
            .padding(.bottom, DesignTokens.Spacing.xxl)
        }
        .scrollDismissesKeyboard(.interactively)
    }
}

#Preview {
    let dependencies = AppDependencies.makeMock()
    InvitePeopleSheet(viewModel: dependencies.makeInvitePeopleViewModel(for: MockGroupFixtures.make(now: .now)[0]),
                      errorCenter: dependencies.errorCenter)
}
