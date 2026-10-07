import SwiftUI

/// When (the start, and a deadline before it), where (place and spot), who can join (the group and the visibility) and
/// the description. Every stored property lives in the main file.
extension TournamentDraftForm {
    /// Whether entries close at the start or earlier; the picker's two segments.
    private enum Deadline: Hashable {
        case atStart, earlier
    }

    var whenSection: some View {
        Section {
            DatePicker(AppBranding.Tournaments.startsAt, selection: $viewModel.draft.startsAt, in: viewModel.earliestStart...)
                .disabled(viewModel.isLocked)
            captioned(Copy.registration) {
                Picker(Copy.registration, selection: deadline) {
                    Text(Copy.deadlineAtStart).tag(Deadline.atStart)
                    Text(Copy.deadlineEarlier).tag(Deadline.earlier)
                }
                .pickerStyle(.segmented)
                .disabled(viewModel.isLocked)
                .accessibilityIdentifier(AccessibilityIdentifiers.tournamentDeadline)
            }
            if viewModel.draft.registrationClosesAt != nil {
                DatePicker(Copy.registrationClosesAt, selection: registrationClosesAt, in: ...viewModel.draft.startsAt)
                    .disabled(viewModel.isLocked)
            }
        } header: {
            Text(Copy.startsAt)
        } footer: {
            issueText(viewModel.issue(for: .startsAtTooSoon, .registrationClosesAfterStart))
        }
    }

    /// Switching the deadline on proposes a day before the start; off clears it.
    private var deadline: Binding<Deadline> {
        Binding {
            viewModel.draft.registrationClosesAt == nil ? .atStart : .earlier
        } set: { choice in
            viewModel.draft.registrationClosesAt = choice == .atStart
                ? nil
                : TournamentDraft.proposedDeadline(before: viewModel.draft.startsAt, now: .now)
        }
    }

    private var registrationClosesAt: Binding<Date> {
        Binding(get: { viewModel.draft.registrationClosesAt ?? viewModel.draft.startsAt },
                set: { viewModel.draft.registrationClosesAt = $0 })
    }

    var whereSection: some View {
        Section {
            TextField(AppBranding.Events.Create.locationNamePlaceholder, text: $viewModel.draft.locationName)
                .textInputAutocapitalization(.words)
                .focused($focusedField, equals: .locationName)
                .submitLabel(.done)
                .accessibilityIdentifier(AccessibilityIdentifiers.tournamentLocationName)
            PlacePickerRow(coordinate: $viewModel.draft.coordinate)
                .accessibilityIdentifier(AccessibilityIdentifiers.createPickOnMap)
        } header: {
            Text(Copy.whereSection)
        } footer: {
            issueText(viewModel.issue(for: .locationNameMissing, .locationNameTooLong, .coordinateMissing))
        }
    }

    /// Which group hosts the tournament (its visibility then follows the group's), or who can join a standalone one.
    var whoSection: some View {
        Section {
            if viewModel.showsGroupRow {
                groupRow
            }
            if viewModel.allowsStructureChanges, viewModel.draft.group == nil {
                Picker(Copy.visibility, selection: $viewModel.draft.visibility) {
                    ForEach(GroupVisibility.allCases, id: \.self) { visibility in
                        Label(visibility.displayName, systemImage: visibility.symbolName).tag(visibility)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier(AccessibilityIdentifiers.tournamentVisibility)
            }
        } header: {
            Text(Copy.visibility)
        } footer: {
            if viewModel.explainsNoEligibleGroups {
                Text(AppBranding.Events.Create.noEligibleGroups)
            } else if viewModel.draft.group == nil, viewModel.allowsStructureChanges {
                Text(viewModel.draft.visibility == .public ? AppBranding.Groups.publicFooter : AppBranding.Groups.privateFooter)
            }
        }
    }

    /// A menu over the groups the organiser may create in, the preset group read-only when the sheet opened from that
    /// group or on an edit, or "No group" read-only when none of the caller's groups lets them host.
    @ViewBuilder private var groupRow: some View {
        if let locked = viewModel.lockedGroup {
            LabeledContent(AppBranding.Events.Create.group, value: locked.name)
                .accessibilityIdentifier(AccessibilityIdentifiers.createGroup)
        } else if viewModel.explainsNoEligibleGroups {
            LabeledContent(AppBranding.Events.Create.group, value: AppBranding.Events.Create.noGroup)
                .accessibilityIdentifier(AccessibilityIdentifiers.createGroup)
        } else {
            Picker(AppBranding.Events.Create.group, selection: $viewModel.draft.group) {
                Text(AppBranding.Events.Create.noGroup).tag(EventGroupRef?.none)
                ForEach(viewModel.eligibleGroups) { group in
                    Text(group.name).tag(EventGroupRef?.some(group))
                }
            }
            .accessibilityIdentifier(AccessibilityIdentifiers.createGroup)
        }
    }

    var detailsSection: some View {
        Section {
            TextField(Copy.descriptionPlaceholder, text: $viewModel.draft.description, axis: .vertical)
                .textInputAutocapitalization(.sentences)
                .lineLimit(DesignTokens.Layout.multilineFieldLines)
        } header: {
            Text(Copy.detailsSection)
        } footer: {
            issueText(viewModel.issue(for: .descriptionTooLong))
        }
    }
}
