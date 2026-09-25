import SwiftUI

/// What an invite leads to and the button that joins: shared by the root invite sheet (a tapped link) and the
/// "Join with code" sheet. A guest is signed in first and joined right after.
struct InvitePreviewContent: View {
    let viewModel: InvitePreviewViewModel
    let dependencies: AppDependencies
    /// The join landed and the chat opened; the sheet around this content closes.
    let onDone: () -> Void
    @State private var isSignInPresented = false
    /// Set while the sign-in asked for by the join button is up, so a sign-in made elsewhere does not join.
    @State private var awaitsSignIn = false

    private typealias Copy = AppBranding.Groups.Invite

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
            ScreenTitle(text: Copy.previewTitle)
            if let preview = viewModel.preview {
                card(preview)
                if preview.isMember {
                    Text(Copy.alreadyMember)
                        .font(LilyTheme.Fonts.caption)
                        .foregroundStyle(.secondary)
                }
                joinButton
            } else if viewModel.loadFailed {
                Button(AppBranding.Groups.tryAgain) { Task { await viewModel.load() } }
                    .lilyGlassButton()
            } else {
                ProgressView().frame(maxWidth: .infinity)
            }
            Spacer()
        }
        .padding(DesignTokens.Spacing.xl)
        .sheet(isPresented: $isSignInPresented) {
            SignInSheet(session: dependencies.sessionController, errorCenter: dependencies.errorCenter)
        }
        // The code stays put through the sign-in; the join simply runs once a user exists.
        .onChange(of: dependencies.sessionController.state.user) {
            guard awaitsSignIn, dependencies.sessionController.state.user != nil else { return }
            awaitsSignIn = false
            Task { await viewModel.join() }
        }
        .onChange(of: viewModel.joinedGroup) {
            if viewModel.joinedGroup != nil { onDone() }
        }
    }

    private func card(_ preview: InvitePreview) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                HStack(spacing: DesignTokens.Spacing.sm) {
                    if let type = preview.group.type {
                        EventTypeChip(type: type)
                    }
                    Label(preview.group.visibility.displayName, systemImage: preview.group.visibility.symbolName)
                        .lilyChip(.regular)
                }
                Text(preview.group.name).font(LilyTheme.Fonts.cardTitle)
                if let description = preview.group.description {
                    Text(description).font(.subheadline).foregroundStyle(.secondary)
                }
                Label(AppBranding.Groups.members(preview.group.memberCount), systemImage: DesignTokens.Symbols.groups)
                    .font(LilyTheme.Fonts.caption)
                    .foregroundStyle(.secondary)
                Text(Copy.expiresAt(preview.expiresAt.formatted(date: .abbreviated, time: .omitted)))
                    .font(LilyTheme.Fonts.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var joinButton: some View {
        Button {
            join()
        } label: {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Text(AppBranding.Groups.joinGroup)
                if viewModel.isJoining {
                    ProgressView()
                        .controlSize(.regular)
                        .accessibilityHidden(true)
                }
            }
        }
        .lilyProminentButton()
        .disabled(!viewModel.canJoin)
        .accessibilityIdentifier(AccessibilityIdentifiers.inviteRedeem)
    }

    private func join() {
        if viewModel.needsSignIn {
            awaitsSignIn = true
            isSignInPresented = true
        } else {
            Task { await viewModel.join() }
        }
    }
}
