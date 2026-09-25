import SwiftUI

/// Invite people to a group: choose how long the invite lasts and how many may use it, then share the link or copy
/// the code. An invite is created for the options shown; changing them makes a new one.
struct InviteSheet: View {
    @State private var viewModel: InviteViewModel
    private let errorCenter: ErrorCenter
    @Environment(\.dismiss) private var dismiss

    private typealias Copy = AppBranding.Groups.Invite

    init(viewModel: InviteViewModel, errorCenter: ErrorCenter) {
        _viewModel = State(initialValue: viewModel)
        self.errorCenter = errorCenter
    }

    var body: some View {
        NavigationStack {
            ContentScreen {
                ScrollView {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
                        option(Copy.expiry,
                               choices: AppConfig.Groups.inviteExpiryChoicesDays,
                               selection: viewModel.expiresInDays,
                               label: Copy.expiryLabel(days:)) { viewModel.expiresInDays = $0 }
                        option(Copy.uses,
                               choices: AppConfig.Groups.inviteUseChoices,
                               selection: viewModel.maxUses,
                               label: Copy.usesLabel) { viewModel.maxUses = $0 }
                        codeCard
                        shareActions
                    }
                    .padding(DesignTokens.Spacing.xl)
                }
            }
            .navigationTitle(Copy.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button(Copy.done) { dismiss() } }
            }
            .tint(Color.lilyAccent)
        }
        .presentationDragIndicator(.visible)
        .errorPopup(errorCenter)
        .task(id: viewModel.options) { await viewModel.create() }
    }

    /// One row of chips for one option; a single choice, like the draft's type.
    private func option(_ title: String,
                        choices: [Int],
                        selection: Int,
                        label: @escaping (Int) -> String,
                        onSelect: @escaping (Int) -> Void) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text(title)
                .font(LilyTheme.Fonts.caption)
                .foregroundStyle(.secondary)
            FlowLayout(spacing: DesignTokens.Spacing.md, rowSpacing: 0) {
                ForEach(choices, id: \.self) { choice in
                    ChoiceChip(title: label(choice), isSelected: choice == selection) { onSelect(choice) }
                }
            }
        }
    }

    private var codeCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                Text(Copy.codeField)
                    .font(LilyTheme.Fonts.caption)
                    .foregroundStyle(.secondary)
                if let code = viewModel.formattedCode {
                    Text(code)
                        .font(LilyTheme.Fonts.inviteCode)
                        .textSelection(.enabled)
                } else {
                    ProgressView()
                }
            }
        }
    }

    private var shareActions: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            // The link is the item; a disabled placeholder URL stands in until the invite arrives.
            ShareLink(item: viewModel.shareURL ?? AppConfig.Groups.inviteLinkBaseURL, message: Text(viewModel.shareText)) {
                Label(Copy.share, systemImage: DesignTokens.Symbols.invite)
            }
            .lilyProminentButton()
            .disabled(!viewModel.canShare)
            .simultaneousGesture(TapGesture().onEnded { viewModel.recordShared() })
            .accessibilityIdentifier(AccessibilityIdentifiers.inviteShare)
            Button(viewModel.codeCopied ? Copy.codeCopied : Copy.copyCode) { viewModel.copyCode() }
                .lilyGlassButton(labelColor: .lilyInk)
                .disabled(!viewModel.canShare)
                .accessibilityIdentifier(AccessibilityIdentifiers.inviteCopy)
        }
    }
}

#Preview {
    let dependencies = AppDependencies.makeMock()
    InviteSheet(viewModel: dependencies.makeInviteViewModel(for: MockGroupFixtures.make(now: .now)[0]),
                errorCenter: dependencies.errorCenter)
}
