import SwiftUI

/// One group two people share, on a profile: the same row as one of the caller's own groups, opening the group's detail
/// through the `EventGroupRef` destination (the summary is not the whole group, so the detail fetches it first).
struct SharedGroupRow: View {
    let group: GroupSummary

    var body: some View {
        NavigationLink(value: group.ref) {
            GroupRowContent(name: group.name, visibility: group.visibility, caption: group.caption, hasUnread: false)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(AccessibilityIdentifiers.groupRow(group.id))
    }
}
