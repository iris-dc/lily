import SwiftUI

/// Every field of a group, for the create and edit sheets: name and description, the event type, where it plays (a
/// public group must say, a private one may), who can join (fixed once created, so the edit sheet leaves it out) and
/// what members may do. Under each section the first thing still wrong with it.
struct GroupDraftForm: View {
    @Binding var draft: GroupDraft
    let issues: [GroupDraft.Issue]
    let allowsVisibilityChoice: Bool

    private typealias Copy = AppBranding.Groups.Create

    var body: some View {
        Form {
            groupSection
            whereSection
            if allowsVisibilityChoice {
                visibilitySection
            }
            permissionsSection
        }
        .scrollContentBackground(.hidden)
        .tint(Color.lilyAccent)
    }

    private var groupSection: some View {
        Section {
            TextField(Copy.nameField, text: $draft.name, prompt: Text(Copy.namePlaceholder))
                .textInputAutocapitalization(.words)
                .accessibilityIdentifier(AccessibilityIdentifiers.createGroupName)
            TextField(Copy.descriptionPlaceholder, text: $draft.description, axis: .vertical)
                .textInputAutocapitalization(.sentences)
                .lineLimit(DesignTokens.Layout.multilineFieldLines)
                .accessibilityIdentifier(AccessibilityIdentifiers.createGroupDescription)
            typeChips
        } header: {
            Text(Copy.groupSection)
        } footer: {
            issueText(first(of: .nameTooShort, .nameTooLong, .descriptionTooLong))
        }
    }

    private var typeChips: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text(Copy.eventType)
                .font(LilyTheme.Fonts.caption)
                .foregroundStyle(.secondary)
            EventTypeChips(anyTitle: Copy.anyType, isSelected: { $0 == draft.type }, onSelect: { draft.type = $0 })
        }
    }

    /// The place the group plays at: Discover orders public groups by it and shows the distance to it.
    private var whereSection: some View {
        Section {
            TextField(AppBranding.Events.Create.locationNamePlaceholder, text: $draft.locationName)
                .textInputAutocapitalization(.words)
                .submitLabel(.done)
                .accessibilityIdentifier(AccessibilityIdentifiers.createGroupLocationName)
            PlacePickerRow(coordinate: $draft.coordinate)
                .accessibilityIdentifier(AccessibilityIdentifiers.createGroupPickOnMap)
        } header: {
            Text(AppBranding.Events.Create.whereSection)
        } footer: {
            if let issue = first(of: .locationNameMissing, .locationNameTooLong, .coordinateMissing) {
                Text(Copy.message(for: issue))
            } else {
                Text(draft.visibility == .public ? Copy.placePublicFooter : Copy.placePrivateFooter)
            }
        }
    }

    private var visibilitySection: some View {
        Section {
            Picker(Copy.visibility, selection: $draft.visibility) {
                ForEach(GroupVisibility.allCases, id: \.self) { visibility in
                    Label(visibility.displayName, systemImage: visibility.symbolName).tag(visibility)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier(AccessibilityIdentifiers.createGroupVisibility)
        } header: {
            Text(Copy.visibility)
        } footer: {
            Text(draft.visibility == .public ? AppBranding.Groups.publicFooter : AppBranding.Groups.privateFooter)
        }
    }

    private var permissionsSection: some View {
        Section {
            Toggle(Copy.membersCanCreateEvents, isOn: $draft.membersCanCreateEvents)
            Toggle(Copy.membersCanInvite, isOn: $draft.membersCanInvite)
        } header: {
            Text(Copy.permissionsSection)
        }
    }

    /// The first of `candidates` the draft has, for the hint under the fields they concern.
    private func first(of candidates: GroupDraft.Issue...) -> GroupDraft.Issue? {
        candidates.first { issues.contains($0) }
    }

    @ViewBuilder
    private func issueText(_ issue: GroupDraft.Issue?) -> some View {
        if let issue {
            Text(Copy.message(for: issue))
        }
    }
}

#Preview {
    @Previewable @State var draft = GroupDraft()
    NavigationStack {
        ContentScreen {
            GroupDraftForm(draft: $draft, issues: draft.issues, allowsVisibilityChoice: true)
        }
    }
}
