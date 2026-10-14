import SwiftUI

/// The roster of a group with the actions the caller has on each row, and, for admins, the banned list with Unban.
/// Removing and banning ask first, through the detail's one dialog; promotions and demotions act at once.
struct MembersList: View {
    let viewModel: MembersViewModel
    /// Hands a destructive row action to the detail, which asks and performs it.
    let confirm: (GroupConfirmation) -> Void

    private typealias Copy = AppBranding.Groups

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            if viewModel.isLoading && viewModel.members.isEmpty {
                ProgressView().frame(maxWidth: .infinity)
            }
            ForEach(viewModel.members) { row(for: $0) }
            if viewModel.showsBans, !viewModel.bans.isEmpty {
                banned
            }
        }
        // A container's identifier would otherwise stamp every row; the rows keep theirs (`member-row-<userId>`).
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityIdentifiers.membersList)
        .task(id: ObjectIdentifier(viewModel)) { await viewModel.load() }
    }

    private var banned: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text(Copy.bannedSection)
                .font(LilyTheme.Fonts.caption)
                .foregroundStyle(.secondary)
                .padding(.top, DesignTokens.Spacing.md)
            ForEach(viewModel.bans) { member in
                MemberRow(member: member, isSelf: false)
                    .contextMenu {
                        Button(Copy.unbanMember) { Task { await viewModel.unban(member) } }
                    }
            }
        }
    }

    /// A row the caller can do nothing to (their own, a plain member's view, an outsider's) gets no menu, so a long
    /// press lifts nothing.
    @ViewBuilder private func row(for member: GroupMember) -> some View {
        let row = MemberRow(member: member, isSelf: viewModel.isSelf(member))
        let actions = viewModel.actions(for: member)
        if actions.isEmpty {
            row
        } else {
            row.contextMenu { menuItems(actions, on: member) }
        }
    }

    @ViewBuilder
    private func menuItems(_ actions: [MembersViewModel.MemberAction], on member: GroupMember) -> some View {
        ForEach(actions, id: \.self) { action in
            Button(role: action.isDestructive ? .destructive : nil) {
                if let confirmation = action.confirmation(for: member) {
                    confirm(confirmation)
                } else {
                    Task { await viewModel.perform(action, on: member) }
                }
            } label: {
                Text(action.title)
            }
        }
    }
}
