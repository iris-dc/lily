import SwiftUI

/// Opens the full roster from the detail's People card. Carries the group itself, so a stack holding two group
/// details builds the right roster from the value, whichever detail's registration answers the push.
nonisolated struct GroupMembersDestination: Hashable {
    let group: SportGroup
}

/// The members screen: the roster with the actions the caller has on each row (`MembersList`), the removal and ban
/// questions asked here. Reads the detail's own view model, so a change made here reaches its People card on the way
/// back.
struct GroupMembersView: View {
    let viewModel: MembersViewModel
    @State private var confirmation: GroupConfirmation?

    var body: some View {
        ContentScreen {
            ScrollView {
                MembersList(viewModel: viewModel) { confirmation = $0 }
                    .padding(DesignTokens.Layout.detailMargin)
                    .readableColumn()
            }
        }
        .navigationTitle(AppBranding.Groups.membersSection)
        .navigationBarTitleDisplayMode(.inline)
        .hidesTabBarOnCompact()
        .confirmationDialog(item: $confirmation,
                            title: { $0.title(groupName: viewModel.group.name) },
                            actions: { confirmationButton(for: $0) })
    }

    private func confirmationButton(for confirmation: GroupConfirmation) -> some View {
        Button(role: .destructive) {
            Task { await run(confirmation) }
        } label: {
            Text(confirmation.buttonTitle)
        }
    }

    /// Only the roster's own questions reach this dialog; leaving and deleting stay with the detail.
    private func run(_ confirmation: GroupConfirmation) async {
        switch confirmation {
        case .remove(let member): await viewModel.perform(.remove, on: member)
        case .ban(let member): await viewModel.perform(.ban, on: member)
        case .leave, .delete: break
        }
    }
}

#Preview {
    let dependencies = AppDependencies.makeMock()
    NavigationStack {
        GroupMembersView(viewModel: dependencies.makeMembersViewModel(for: MockGroupFixtures.make(now: .now)[0],
                                                                      onChange: { _ in }))
    }
}
