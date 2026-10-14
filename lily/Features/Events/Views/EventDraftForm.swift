import SwiftUI

/// Every field of a game, new or the host's own, grouped the way a host thinks: the game, where, how many, and optional
/// details. Under each group the first thing still wrong with it, so a disabled Create or Save button is never a mystery.
struct EventDraftForm<Model: EventDraftEditing>: View {
    @Bindable var viewModel: Model
    @FocusState private var focusedField: Field?

    private enum Field { case title, locationName }

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
                groupRow
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

    /// Single choice in the filter panel's chip look; one type is always selected.
    private var typeChips: some View {
        CaptionedControl(Copy.eventType) {
            EventTypeChips(isSelected: { $0 == viewModel.draft.type }, onSelect: { type in
                if let type { viewModel.draft.type = type }
            })
        }
    }

    /// Which group hosts the game: a menu over the groups the host may create in, the preset group read-only when
    /// the sheet opened from that group, or "No group" read-only when none of the caller's groups lets them host.
    @ViewBuilder private var groupRow: some View {
        if let locked = viewModel.lockedGroup {
            LabeledContent(Copy.group, value: locked.name)
                .accessibilityIdentifier(AccessibilityIdentifiers.createGroup)
        } else if viewModel.explainsNoEligibleGroups {
            LabeledContent(Copy.group, value: Copy.noGroup)
                .accessibilityIdentifier(AccessibilityIdentifiers.createGroup)
        } else {
            Picker(Copy.group, selection: $viewModel.draft.group) {
                Text(Copy.noGroup).tag(EventGroupRef?.none)
                ForEach(viewModel.eligibleGroups) { group in
                    Text(group.name).tag(EventGroupRef?.some(group))
                }
            }
            .accessibilityIdentifier(AccessibilityIdentifiers.createGroup)
        }
    }

    private var whereSection: some View {
        Section {
            PlaceFields(name: $viewModel.draft.locationName,
                        coordinate: $viewModel.draft.coordinate,
                        nameIdentifier: AccessibilityIdentifiers.createLocationName,
                        pickerIdentifier: AccessibilityIdentifiers.createPickOnMap,
                        focus: $focusedField,
                        equals: .locationName)
        } header: {
            Text(Copy.whereSection)
        } footer: {
            viewModel.issue(for: .locationNameMissing, .locationNameTooLong, .coordinateMissing)
                .map { Text(Copy.message(for: $0)) }
        }
    }

    /// Whether the game takes any number, up to a cap or at least a number it needs, and that number when there is
    /// one; the stepper's label repeats which of the two it is.
    private var playersSection: some View {
        Section {
            Picker(Copy.playersSection, selection: $viewModel.draft.playerLimit) {
                ForEach(PlayerLimit.allCases, id: \.self) { limit in
                    Text(Copy.name(for: limit)).tag(limit)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier(AccessibilityIdentifiers.createPlayerLimit)
            if viewModel.draft.playerLimit.hasCapacity {
                Stepper(value: $viewModel.draft.capacity, in: viewModel.capacityRange) {
                    Text(Copy.capacity(viewModel.draft.capacity, needed: viewModel.draft.allowsExtraParticipants))
                }
                .accessibilityIdentifier(AccessibilityIdentifiers.createCapacity)
            }
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
            TextField(Copy.descriptionPlaceholder, text: $viewModel.draft.description, axis: .vertical)
                .textInputAutocapitalization(.sentences)
                .lineLimit(DesignTokens.Layout.multilineFieldLines)
            TextField(Copy.lookingForPlaceholder, text: $viewModel.draft.lookingFor)
                .textInputAutocapitalization(.sentences)
            SkillLevelPicker(selection: $viewModel.draft.skillLevel)
            priceRow
        } header: {
            Text(Copy.detailsSection)
        } footer: {
            viewModel.issue(for: .descriptionTooLong, .lookingForTooLong, .priceUnreadable, .priceOutOfRange)
                .map { Text(Copy.message(for: $0)) }
        }
    }

    /// Empty or zero means free. The draft holds the text and reads it as an amount on every change, so Create never
    /// races a pending commit of the decimal pad, which has no return key.
    private var priceRow: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            Text(Copy.price)
            Spacer()
            TextField(Copy.pricePlaceholder, text: $viewModel.draft.priceText)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: DesignTokens.Layout.priceFieldWidth)
                .accessibilityIdentifier(AccessibilityIdentifiers.createPrice)
                .accessibilityLabel(Copy.price)
            Text(Price.symbol(for: viewModel.draft.currencyCode))
                .foregroundStyle(.secondary)
                .accessibilityIdentifier(AccessibilityIdentifiers.createPriceCurrency)
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
