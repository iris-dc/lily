import SwiftUI

/// The roster of a group with the actions the caller has on each row, and, for admins, the banned list with Unban.
/// Removing and banning ask first; promotions and demotions act at once.
struct MembersList: View {
    let viewModel: MembersViewModel
    @State private var pending: PendingMemberAction?

    private typealias Copy = AppBranding.Groups

    /// A destructive row action waiting for the caller's word.
    private struct PendingMemberAction: Identifiable {
        let action: MembersViewModel.MemberAction
        let member: GroupMember

        var id: String { "\(action)-\(member.userId)" }

        var title: String {
            action.confirmationTitle(memberName: member.displayName) ?? action.title
        }
    }

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
        .confirmationDialog(pending?.title ?? "",
                            isPresented: isConfirming,
                            titleVisibility: .visible,
                            presenting: pending) { pending in
            Button(role: .destructive) {
                Task { await viewModel.perform(pending.action, on: pending.member) }
            } label: {
                Text(pending.action.title)
            }
        }
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
                if action.isDestructive {
                    pending = PendingMemberAction(action: action, member: member)
                } else {
                    Task { await viewModel.perform(action, on: member) }
                }
            } label: {
                Text(action.title)
            }
        }
    }

    private var isConfirming: Binding<Bool> {
        Binding(get: { pending != nil }, set: { if !$0 { pending = nil } })
    }
}
