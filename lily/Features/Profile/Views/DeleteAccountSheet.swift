import SwiftUI

/// The delete-account flow (the deletion contract): the advisory counts summary with the always-true messages
/// sentence, the destructive confirmation, the locked wait while the backend's job is claimed and the poll settles,
/// and the one-time acknowledgment the sheet itself hosts — only its tap ends the session, so the surface it lives on
/// survives to be acknowledged (the relocation contract's teardown order). Presented from Settings and from the terms
/// sheet alike; mounts its own popup, since a sheet is drawn above the root's.
struct DeleteAccountSheet: View {
    @State private var viewModel: DeleteAccountViewModel
    private let errorCenter: ErrorCenter
    @State private var isConfirming = false
    @Environment(\.dismiss) private var dismiss

    private typealias Copy = AppBranding.DeleteAccount

    init(viewModel: DeleteAccountViewModel, errorCenter: ErrorCenter) {
        _viewModel = State(initialValue: viewModel)
        self.errorCenter = errorCenter
    }

    var body: some View {
        NavigationStack {
            ContentScreen {
                if viewModel.isDeleted {
                    acknowledgment
                } else if viewModel.isDeleting {
                    deleting
                } else {
                    summary
                }
            }
            .navigationTitle(Copy.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .tint(Color.lilyAccent)
        }
        .presentationDetents([.large])
        .lilyFormSheet(errorCenter: errorCenter, lockedWhile: viewModel.isLocked)
        .task { await viewModel.prepare() }
        .confirmationDialog(Copy.dialogTitle, isPresented: $isConfirming, titleVisibility: .visible) {
            Button(Copy.confirmAction, role: .destructive) {
                Task { await viewModel.confirmDeletion() }
            }
        } message: {
            Text(Copy.irreversible)
        }
    }

    /// What deleting touches, each consequence a marked row: one plural line per non-zero count (zero rows dropped),
    /// the counts framed as approximate, and the messages sentence unconditionally, so an account owning nothing
    /// still reads it.
    private var summary: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                    if viewModel.isLoadingPlan {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    }
                    consequenceList
                    footnotes
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollBounceBehavior(.basedOnSize)
            confirmButton
        }
        .padding(DesignTokens.Spacing.xl)
        .readableColumn()
    }

    /// The view model's non-zero rows, then the always-true messages sentence as the same list's last row. The accent
    /// sits on the marks (never on body text); the words stay ink, and each mark says nothing on its own.
    private var consequenceList: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            ForEach(consequences) { row in
                Label {
                    Text(row.text)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: Self.symbol(for: row.kind))
                        .foregroundStyle(Color.lilyAccent)
                        .accessibilityHidden(true)
                }
                .labelStyle(.iconColumn)
            }
        }
    }

    private var consequences: [DeletionConsequence] {
        viewModel.summaryRows + [DeletionConsequence(kind: .messages, text: Copy.messagesSentence)]
    }

    private var footnotes: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            if !viewModel.summaryRows.isEmpty {
                Text(Copy.approximate)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Text(Copy.irreversible)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private static func symbol(for kind: DeletionConsequence.Kind) -> String {
        switch kind {
        case .groupsTransferring: DesignTokens.Symbols.deletionGroupsTransferring
        case .groupsDeleted: DesignTokens.Symbols.deletionGroupsDeleted
        case .eventsCancelled: DesignTokens.Symbols.deletionEventsCancelled
        case .entriesWithdrawn: DesignTokens.Symbols.deletionEntriesWithdrawn
        case .tournamentsCancelled: DesignTokens.Symbols.deletionTournamentsCancelled
        case .messages: DesignTokens.Symbols.deletionMessages
        }
    }

    private var confirmButton: some View {
        Button(Copy.title) { isConfirming = true }
            .lilyProminentButton()
            .accessibilityIdentifier(AccessibilityIdentifiers.deleteAccountConfirm)
    }

    private var deleting: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            ProgressView()
            Text(Copy.deleting)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    /// The one-time acknowledgment; only this tap triggers the account-deleted session end, which collapses the sheet
    /// with everything under it over the signed-out landing.
    private var acknowledgment: some View {
        VStack(spacing: DesignTokens.Spacing.xl) {
            EmptyStateView(symbolName: Tombstone.symbol, title: Copy.deletedTitle, message: Copy.deletedMessage)
            Button(Copy.acknowledgeAction) {
                Task { await viewModel.acknowledge() }
            }
            .lilyProminentButton()
            .accessibilityIdentifier(AccessibilityIdentifiers.deleteAccountAcknowledge)
            .padding(.bottom, DesignTokens.Spacing.xl)
        }
    }

    /// Cancel leaves only before the confirm; past it the flow owns the sheet.
    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        if !viewModel.isLocked {
            ToolbarItem(placement: .cancellationAction) {
                Button(AppBranding.Forms.cancel, role: .cancel) { dismiss() }
                    .lilyToolbarTextButton()
                    .accessibilityIdentifier(AccessibilityIdentifiers.deleteAccountCancel)
            }
        }
    }
}

#Preview {
    let dependencies = AppDependencies.makeMock()
    DeleteAccountSheet(viewModel: dependencies.makeDeleteAccountViewModel(), errorCenter: dependencies.errorCenter)
}
