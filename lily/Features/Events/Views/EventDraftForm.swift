import SwiftUI

/// Every field of a game, new or the host's own, grouped the way a host thinks: the game, where, how many, and optional
/// details. Under each group the first thing still wrong with it, so a disabled Create or Save button is never a mystery.
/// Section contents are standalone views the sections recompose (`HostingGroupRow`, `EventPlayersFields`,
/// `EventDetailsFields`, and the Where parts in `+Place`); headers and first-issue footers stay here.
struct EventDraftForm<Model: EventDraftEditing>: View {
    @Bindable var viewModel: Model
    @FocusState var focusedField: Field?
    /// Places offered for what is typed into the name field, filled by `PlaceNameField`'s debounced machinery and
    /// drawn by the Where section's rows; owned here because the field and the rows are separate rows of one section.
    @State var suggestions: [PlaceSuggestion] = []

    enum Field { case title, locationName }

    private typealias Copy = AppBranding.Events.Create

    var body: some View {
        Form {
            gameSection
            whereSection
            playersSection
            detailsSection
        }
        .scrollContentBackground(.hidden)
        .readableColumn()
        .tint(Color.lilyAccent)
        // The row's own clear sits on a row a Form culls off-viewport; this belt on the never-removed Form guarantees
        // leaving the field always empties the rows, mounted or not, and is idempotent with the row-level clear.
        .onChange(of: focusedField) {
            if focusedField != .locationName { suggestions = [] }
        }
    }

    private var gameSection: some View {
        Section {
            TextField(Copy.titleField, text: $viewModel.draft.title, prompt: Text(Copy.titlePlaceholder))
                .textInputAutocapitalization(.sentences)
                .focused($focusedField, equals: .title)
                .submitLabel(.next)
                .onSubmit { focusedField = .locationName }
                .accessibilityIdentifier(AccessibilityIdentifiers.createTitle)
            typeChips
            DatePicker(Copy.startsAt, selection: $viewModel.draft.startsAt, in: viewModel.earliestStart...)
            if viewModel.showsGroupRow {
                HostingGroupRow(lockedGroup: viewModel.lockedGroup,
                                showsNoEligibleGroups: viewModel.explainsNoEligibleGroups,
                                eligibleGroups: viewModel.eligibleGroups,
                                selection: $viewModel.draft.group)
            }
        } header: {
            Text(Copy.gameSection)
        } footer: {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                viewModel.issue(for: .titleMissing, .titleTooLong, .startsAtTooSoon).map { Text(Copy.message(for: $0)) }
                if viewModel.explainsNoEligibleGroups {
                    Text(Copy.noEligibleGroups)
                }
            }
        }
    }

    /// Single choice in the filter sheet's chip look; one type is always selected.
    private var typeChips: some View {
        CaptionedControl(Copy.eventType) {
            EventTypeChips(isSelected: { $0 == viewModel.draft.type }, onSelect: { type in
                if let type { viewModel.draft.type = type }
            })
        }
    }

    private var playersSection: some View {
        Section {
            EventPlayersFields(viewModel: viewModel)
        } header: {
            Text(Copy.playersSection)
        } footer: {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                if let hint = Copy.hint(for: viewModel.draft.playerLimit) {
                    Text(hint)
                }
                viewModel.issue(for: .capacityOutOfRange, .capacityBelowParticipants).map { Text(Copy.message(for: $0)) }
            }
        }
    }

    private var detailsSection: some View {
        Section {
            EventDetailsFields(viewModel: viewModel)
        } header: {
            Text(Copy.detailsSection)
        } footer: {
            viewModel.issue(for: .descriptionTooLong, .lookingForTooLong, .priceUnreadable, .priceOutOfRange)
                .map { Text(Copy.message(for: $0)) }
        }
    }
}

#Preview {
    let dependencies = AppDependencies.makeMock()
    NavigationStack {
        ContentScreen {
            EventDraftForm(viewModel: dependencies.makeCreateEventViewModel { _ in })
        }
    }
}
