import SwiftUI

/// The "more" menu of a group's detail, for members: invite, edit, leave, report, delete; only what `GroupAccess`
/// allows appears. Leaving and deleting go through the caller's confirmation first.
struct GroupDetailMenu: View {
    let viewModel: GroupDetailViewModel
    let onInvite: () -> Void
    let onCreateTournament: () -> Void
    let onEdit: () -> Void
    let onLeave: () -> Void
    let onDelete: () -> Void

    private typealias Copy = AppBranding.Groups

    private var group: SportGroup { viewModel.group }
    private var access: GroupAccess { viewModel.access }

    var body: some View {
        Menu {
            if access.canInvite(in: group) {
                Button(Copy.invite, systemImage: DesignTokens.Symbols.invite, action: onInvite)
            }
            if AppConfig.FeatureFlags.tournaments, access.canCreateEvents(in: group) {
                Button(AppBranding.Tournaments.Create.menuItem,
                       systemImage: DesignTokens.Symbols.tournament,
                       action: onCreateTournament)
            }
            if access.canEdit {
                Button(Copy.edit, systemImage: DesignTokens.Symbols.edit, action: onEdit)
            }
            if access.canLeave {
                Button(Copy.leave, systemImage: DesignTokens.Symbols.leave, role: .destructive, action: onLeave)
                    .accessibilityIdentifier(AccessibilityIdentifiers.groupLeave)
            }
            // Reporting arrives with moderation; the entry is here so the menu's shape is final.
            Button(Copy.reportGroup, systemImage: DesignTokens.Symbols.report) {}
                .disabled(true)
            if access.canDelete {
                Button(Copy.delete, systemImage: DesignTokens.Symbols.delete, role: .destructive, action: onDelete)
            }
        } label: {
            Label(Copy.title, systemImage: DesignTokens.Symbols.more)
        }
        .accessibilityIdentifier(AccessibilityIdentifiers.groupMore)
    }
}
