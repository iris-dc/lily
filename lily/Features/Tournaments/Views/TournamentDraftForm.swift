import SwiftUI

/// Every field of a tournament, new or the organiser's own, grouped the way an organiser thinks: the tournament, where,
/// when, the entries, who can join, and the optional description. Under each group the first thing still wrong with it.
/// Segmented pickers throughout, never a toggle. The Where, When and Who sections are in the `+Schedule` file. Where
/// follows the first section as on the event form: a `Form` instantiates rows only near the viewport, and the UI tests
/// (and a user with the keyboard up) reach the place field without a scroll this way.
struct TournamentDraftForm<Model: TournamentDraftEditing>: View {
    @Bindable var viewModel: Model
    @FocusState var focusedField: Field?

    enum Field { case name, locationName }

    typealias Copy = AppBranding.Tournaments.Create

    var body: some View {
        Form {
            tournamentSection
            whereSection
            whenSection
            entriesSection
            if viewModel.showsGroupRow || viewModel.allowsStructureChanges {
                whoSection
            }
            detailsSection
        }
        .scrollContentBackground(.hidden)
        .readableColumn()
        .tint(Color.lilyAccent)
    }

    private var tournamentSection: some View {
        Section {
            TextField(Copy.nameField, text: $viewModel.draft.name, prompt: Text(Copy.namePlaceholder))
                .textInputAutocapitalization(.words)
                .focused($focusedField, equals: .name)
                .submitLabel(.next)
                .onSubmit { focusedField = .locationName }
                .accessibilityIdentifier(AccessibilityIdentifiers.tournamentName)
            if viewModel.allowsStructureChanges {
                typeChips
                formatPicker
            }
        } header: {
            Text(Copy.tournamentSection)
        } footer: {
            issueText(viewModel.issue(for: .nameTooShort, .nameTooLong))
        }
    }

    /// Single choice in the filter panel's chip look; one type is always selected.
    private var typeChips: some View {
        captioned(Copy.eventType) {
            EventTypeChips(isSelected: { $0 == viewModel.draft.type }, onSelect: { type in
                if let type { viewModel.draft.type = type }
            })
        }
    }

    /// Changing the format pulls the entries back under its cap.
    private var formatPicker: some View {
        captioned(Copy.format) {
            Picker(Copy.format, selection: $viewModel.draft.format) {
                ForEach(TournamentFormat.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier(AccessibilityIdentifiers.tournamentFormat)
            .onChange(of: viewModel.draft.format) {
                viewModel.draft.maxEntries = min(viewModel.draft.maxEntries, viewModel.entriesRange.upperBound)
            }
        }
    }

    /// Team size (fixed once created), the entries cap (fixed after the start) and whether a match may end level.
    private var entriesSection: some View {
        Section {
            if viewModel.allowsStructureChanges {
                Stepper(value: $viewModel.draft.teamSize, in: AppConfig.Tournaments.teamSizeRange) {
                    Text(Copy.teamSize(viewModel.draft.teamSize))
                }
                .accessibilityIdentifier(AccessibilityIdentifiers.tournamentTeamSize)
            }
            Stepper(value: $viewModel.draft.maxEntries, in: viewModel.entriesRange) {
                Text(Copy.maxEntries(viewModel.draft.maxEntries, teamSize: viewModel.draft.teamSize))
            }
            .disabled(viewModel.isLocked)
            .accessibilityIdentifier(AccessibilityIdentifiers.tournamentMaxEntries)
            captioned(Copy.draws) {
                Picker(Copy.draws, selection: allowsDraws) {
                    Text(Copy.drawsAllowed).tag(true)
                    Text(Copy.drawsNotAllowed).tag(false)
                }
                .pickerStyle(.segmented)
                .disabled(viewModel.isLocked)
                .accessibilityIdentifier(AccessibilityIdentifiers.tournamentDraws)
            }
        } header: {
            Text(Copy.entries)
        } footer: {
            issueText(viewModel.issue(for: .teamSizeOutOfRange, .maxEntriesOutOfRange, .maxEntriesBelowEntries))
        }
    }

    /// The draft follows the type's default until the organiser picks; the picker shows the resolved choice.
    private var allowsDraws: Binding<Bool> {
        Binding(get: { viewModel.draft.resolvedAllowsDraws }, set: { viewModel.draft.allowsDraws = $0 })
    }

    @ViewBuilder
    func issueText(_ issue: TournamentDraft.Issue?) -> some View {
        if let issue {
            Text(Copy.message(for: issue, format: viewModel.draft.format))
        }
    }

    /// A segmented picker in a `Form` draws no label of its own, so the caption above names the control, as the type
    /// chips' does ("Allowed | Not allowed" alone said nothing about draws).
    func captioned(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text(title)
                .font(LilyTheme.Fonts.caption)
                .foregroundStyle(.secondary)
            content()
        }
    }
}

#Preview {
    let dependencies = AppDependencies.makeMock()
    NavigationStack {
        ContentScreen {
            TournamentDraftForm(viewModel: dependencies.makeCreateTournamentViewModel { _ in })
        }
    }
}
