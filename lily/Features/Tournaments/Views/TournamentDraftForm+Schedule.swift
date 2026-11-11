import SwiftUI

/// When (the start, and a deadline before it), where (place and spot), the hosting group and the description.
/// Every stored property lives in the main file.
extension TournamentDraftForm {
    var whenSection: some View {
        Section {
            TournamentScheduleFields(viewModel: viewModel)
        } header: {
            Text(Copy.startsAt)
        } footer: {
            viewModel.issue(for: .startsAtTooSoon, .registrationClosesAfterStart)
                .map { Text(Copy.message(for: $0, format: viewModel.draft.format)) }
        }
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

    /// The group hosting the tournament, read-only: the group cannot change on an edit, and the visibility follows it.
    var whoSection: some View {
        Section {
            HostingGroupRow(lockedGroup: viewModel.lockedGroup,
                            showsNoEligibleGroups: viewModel.explainsNoEligibleGroups,
                            eligibleGroups: viewModel.eligibleGroups,
                            selection: $viewModel.draft.group)
        } header: {
            Text(Copy.visibility)
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
