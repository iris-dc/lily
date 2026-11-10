import SwiftUI

/// Which group hosts the game or the tournament: a menu over the groups the caller may create in, the preset group
/// read-only when the sheet opened from that group or on an edit, or "No group" read-only when none of the caller's
/// groups lets them host. The one group row of the event and tournament forms, which share its copy and identifier.
struct HostingGroupRow: View {
    let lockedGroup: EventGroupRef?
    let showsNoEligibleGroups: Bool
    let eligibleGroups: [EventGroupRef]
    @Binding var selection: EventGroupRef?

    private typealias Copy = AppBranding.Events.Create

    var body: some View {
        if let locked = lockedGroup {
            LabeledContent(Copy.group, value: locked.name)
                .accessibilityIdentifier(AccessibilityIdentifiers.createGroup)
        } else if showsNoEligibleGroups {
            LabeledContent(Copy.group, value: Copy.noGroup)
                .accessibilityIdentifier(AccessibilityIdentifiers.createGroup)
        } else {
            Picker(Copy.group, selection: $selection) {
                Text(Copy.noGroup).tag(EventGroupRef?.none)
                ForEach(eligibleGroups) { group in
                    Text(group.name).tag(EventGroupRef?.some(group))
                }
            }
            .lilyMenuPicker()
            .accessibilityIdentifier(AccessibilityIdentifiers.createGroup)
        }
    }
}
