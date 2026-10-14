import SwiftUI

/// The "more" menu of a group's detail, for members and for any signed-in reader of a public group, who gets Report
/// group alone: invite, edit, leave, report, delete; only what `GroupAccess` allows appears. Leaving and deleting go
/// through the caller's confirmation first.
struct GroupDetailMenu: View {
    let viewModel: GroupDetailViewModel
    let onInvite: () -> Void
    let onCreateTournament: () -> Void
    let onEdit: () -> Void
    let onLeave: () -> Void
    let onReport: () -> Void
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
            if viewModel.canReport {
                Button(Copy.reportGroup, systemImage: DesignTokens.Symbols.report, action: onReport)
                    .accessibilityIdentifier(AccessibilityIdentifiers.groupReport)
            }
            if access.canDelete {
                Button(Copy.delete, systemImage: DesignTokens.Symbols.delete, role: .destructive, action: onDelete)
            }
        } label: {
            Label(Copy.title, systemImage: DesignTokens.Symbols.more)
        }
        .accessibilityIdentifier(AccessibilityIdentifiers.groupMore)
    }
}
