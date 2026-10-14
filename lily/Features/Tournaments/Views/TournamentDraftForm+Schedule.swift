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
            CaptionedControl(Copy.registration) {
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
            viewModel.issue(for: .startsAtTooSoon, .registrationClosesAfterStart)
                .map { Text(Copy.message(for: $0, format: viewModel.draft.format)) }
        }
    }

    /// Switching the deadline on proposes a day before the start; off clears it.
    private var deadline: Binding<Deadline> {
        Binding {
            viewModel.draft.registrationClosesAt == nil ? .atStart : .earlier
        } set: { choice in
            viewModel.draft.registrationClosesAt = choice == .atStart ? nil : viewModel.proposedDeadline()
        }
    }

    private var registrationClosesAt: Binding<Date> {
        Binding(get: { viewModel.draft.registrationClosesAt ?? viewModel.draft.startsAt },
                set: { viewModel.draft.registrationClosesAt = $0 })
    }

    var whereSection: some View {
        Section {
            PlaceFields(name: $viewModel.draft.locationName,
                        coordinate: $viewModel.draft.coordinate,
                        nameIdentifier: AccessibilityIdentifiers.tournamentLocationName,
                        pickerIdentifier: AccessibilityIdentifiers.createPickOnMap,
                        focus: $focusedField,
                        equals: .locationName)
        } header: {
            Text(Copy.whereSection)
        } footer: {
            viewModel.issue(for: .locationNameMissing, .locationNameTooLong, .coordinateMissing)
                .map { Text(Copy.message(for: $0, format: viewModel.draft.format)) }
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
            viewModel.issue(for: .descriptionTooLong).map { Text(Copy.message(for: $0, format: viewModel.draft.format)) }
        }
    }
}
