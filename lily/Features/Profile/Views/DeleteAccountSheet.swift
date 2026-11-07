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

    /// What deleting touches: one plural line per non-zero count (zero lines dropped), the counts framed as
    /// approximate, and the messages sentence unconditionally, so an account owning nothing still reads it.
    private var summary: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                    if viewModel.isLoadingPlan {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    }
                    ForEach(viewModel.summaryLines, id: \.self) { line in
                        Text(line)
                    }
                    if !viewModel.summaryLines.isEmpty {
                        Text(Copy.approximate)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Text(Copy.messagesSentence)
                    Text(Copy.irreversible)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollBounceBehavior(.basedOnSize)
            confirmButton
        }
        .padding(DesignTokens.Spacing.xl)
        .readableColumn()
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
