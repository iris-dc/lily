import SwiftUI

/// Every field of a game, new or the host's own, grouped the way a host thinks: the game, where, how many, and optional
/// details. Under each group the first thing still wrong with it, so a disabled Create or Save button is never a mystery.
struct EventDraftForm<Model: EventDraftEditing>: View {
    @Bindable var viewModel: Model
    /// The price field edits text and parses on every change (like the filter's cap), so Create never races a pending
    /// commit of the decimal pad, which has no return key. Seeded from the draft, so an edit shows the game's price.
    @State private var priceText: String
    @FocusState private var focusedField: Field?

    private enum Field { case title, locationName }

    private typealias Copy = AppBranding.Events.Create

    init(viewModel: Model) {
        self.viewModel = viewModel
        _priceText = State(initialValue: viewModel.draft.price.map { $0.formatted(Price.inputFormat) } ?? "")
    }

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
                issueText(viewModel.issue(for: .titleMissing, .titleTooLong, .startsAtTooSoon))
                if viewModel.explainsNoEligibleGroups {
                    Text(Copy.noEligibleGroups)
                }
            }
        }
    }

    /// Single choice in the filter panel's chip look; one type is always selected.
    private var typeChips: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text(Copy.eventType)
                .font(LilyTheme.Fonts.caption)
                .foregroundStyle(.secondary)
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
            TextField(Copy.locationNamePlaceholder, text: $viewModel.draft.locationName)
                .textInputAutocapitalization(.words)
                .focused($focusedField, equals: .locationName)
                .submitLabel(.done)
                .accessibilityIdentifier(AccessibilityIdentifiers.createLocationName)
            PlacePickerRow(coordinate: $viewModel.draft.coordinate)
                .accessibilityIdentifier(AccessibilityIdentifiers.createPickOnMap)
        } header: {
            Text(Copy.whereSection)
        } footer: {
            issueText(viewModel.issue(for: .locationNameMissing, .locationNameTooLong, .coordinateMissing))
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
                issueText(viewModel.issue(for: .capacityOutOfRange, .capacityBelowParticipants))
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
            levelPicker
            priceRow
        } header: {
            Text(Copy.detailsSection)
        } footer: {
            issueText(viewModel.issue(for: .descriptionTooLong, .lookingForTooLong, .priceOutOfRange))
        }
    }

    private var levelPicker: some View {
        Picker(Copy.level, selection: $viewModel.draft.skillLevel) {
            Text(Copy.anyLevel).tag(SkillLevel?.none)
            ForEach(SkillLevel.allCases, id: \.self) { level in
                Text(level.displayName).tag(SkillLevel?.some(level))
            }
        }
    }

    /// Empty or zero means free. The text is the source while typing; the draft is parsed from it on every change.
    private var priceRow: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            Text(Copy.price)
            Spacer()
            TextField(Copy.pricePlaceholder, text: $priceText)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: DesignTokens.Layout.filterPriceFieldWidth)
                .accessibilityIdentifier(AccessibilityIdentifiers.createPrice)
                .accessibilityLabel(Copy.price)
            Text(Price.symbol(for: AppConfig.Events.marketCurrencyCode))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
        .onChange(of: priceText) {
            viewModel.draft.price = Price.parseAmount(priceText)
        }
    }

    @ViewBuilder
    private func issueText(_ issue: EventDraft.Issue?) -> some View {
        if let issue {
            Text(Copy.message(for: issue))
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
