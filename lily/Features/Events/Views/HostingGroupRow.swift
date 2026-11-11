import SwiftUI

/// Which group hosts the game or the tournament: a menu over the groups the caller may create in, the preset group
/// read-only when the sheet opened from that group or on an edit, or "No group" read-only when none of the caller's
/// groups lets them host. The one group row of the event and tournament forms, which share its copy and identifier.
/// The choice is a `Menu` whose label is the whole row, not a bare menu picker, so a tap anywhere across the row
/// opens it (the owner's fourth design round; a menu picker answers only on its value side).
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
            Menu {
                Picker(Copy.group, selection: $selection) {
                    Text(Copy.noGroup).tag(EventGroupRef?.none)
                    ForEach(eligibleGroups) { group in
                        Text(group.name).tag(EventGroupRef?.some(group))
                    }
                }
            } label: {
                LabeledContent(Copy.group) {
                    HStack(spacing: DesignTokens.Spacing.xs) {
                        Text(selection?.name ?? Copy.noGroup)
                        Image(systemName: DesignTokens.Symbols.menuChevron)
                            .font(LilyTheme.Fonts.caption)
                            .accessibilityHidden(true)
                    }
                    .foregroundStyle(.secondary)
                }
                .contentShape(.rect)
            }
            // The title reads as ink like every form row's; a menu label would otherwise take the accent tint.
            .tint(Color.lilyInk)
            .accessibilityIdentifier(AccessibilityIdentifiers.createGroup)
        }
    }
}
