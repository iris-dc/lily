import SwiftUI

/// When (the start, and a deadline before it), where (place and spot), who can join (the group and the visibility) and
/// the description. Every stored property lives in the main file.
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

    /// Which group hosts the tournament (its visibility then follows the group's), or who can join a standalone one.
    var whoSection: some View {
        Section {
            TournamentWhoMayJoinControls(viewModel: viewModel)
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
