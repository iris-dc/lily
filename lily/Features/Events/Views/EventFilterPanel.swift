import SwiftUI

/// Every filter criterion in one panel: type chips, distance, a price input, level, dates and open spots.
struct EventFilterPanel: View {
    let viewModel: EventListViewModel
    let onDone: () -> Void
    /// The field edits text and parses on every change, so Reset, "Free only" and Done never race a pending commit.
    @State private var priceText = ""
    @FocusState private var isPriceFocused: Bool

    private typealias Copy = AppBranding.Events.Filter

    var body: some View {
        DropdownPanel(title: Copy.title,
                      scrolls: true,
                      accessory: {
                          if viewModel.filter.isActive {
                              resetButton
                          }
                      },
                      onDone: onDone,
                      content: {
                          CaptionedControl(Copy.eventType) { typeChips }
                          CaptionedControl(Copy.distance) { distanceChoice }
                          CaptionedControl(Copy.maxPrice) { priceRow }
                          levelRow
                          datesSection
                          Toggle(Copy.openSpotsOnly, isOn: binding(\.openSpotsOnly))
                      })
    }

    /// Shown in the title row while any criterion is active.
    private var resetButton: some View {
        Button {
            viewModel.clearFilter()
        } label: {
            Text(Copy.reset).tappableLabel()
        }
        .buttonStyle(.borderless)
        .font(LilyTheme.Fonts.caption)
    }

    /// Multi-select; "Any type" is on while nothing is chosen.
    private var typeChips: some View {
        EventTypeChips(anyTitle: Copy.anyType,
                       anyIdentifier: AccessibilityIdentifiers.filterTypeAny,
                       isSelected: { type in type.map(viewModel.filter.includes) ?? viewModel.filter.types.isEmpty },
                       onSelect: { type in
                           if let type {
                               viewModel.toggleType(type)
                           } else {
                               viewModel.updateFilter { $0.types = [] }
                           }
                       },
                       identifier: AccessibilityIdentifiers.filterType)
    }

    /// Distance from the user's position. Without a position the criterion cannot be judged, so the choice is replaced
    /// by a note.
    @ViewBuilder private var distanceChoice: some View {
        if viewModel.userLocation == nil {
            Text(Copy.locationUnavailable)
                .font(LilyTheme.Fonts.caption)
                .foregroundStyle(.secondary)
        } else {
            Picker(Copy.distance, selection: binding(\.maxDistanceMeters)) {
                ForEach(AppConfig.Events.filterRadiiMeters, id: \.self) { meters in
                    Text(Measurement(value: meters, unit: UnitLength.meters).roadText()).tag(Double?.some(meters))
                }
                Text(Copy.anywhere).tag(Double?.none)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }

    /// Free-form cap: empty means any price, zero means free games only (the chip sets and shows that zero).
    private var priceRow: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            ChoiceChip(title: Copy.freeOnly, isSelected: viewModel.filter.maxPrice == 0) {
                viewModel.updateFilter { $0.maxPrice = $0.maxPrice == 0 ? nil : 0 }
            }
            .accessibilityIdentifier(AccessibilityIdentifiers.filterFreeOnly)
            Spacer()
            priceField
        }
    }

    /// Drawn like the compact date pickers' capsule, so the trailing controls read as one family. The text is the
    /// source while typing (`applyTypedCap`); only a value set elsewhere (Reset, the chip) rewrites it.
    private var priceField: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            TextField(Copy.anyPrice, text: $priceText)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .focused($isPriceFocused)
                .frame(width: DesignTokens.Layout.priceFieldWidth)
                .accessibilityIdentifier(AccessibilityIdentifiers.filterMaxPrice)
                .accessibilityLabel(Copy.maxPrice)
            Text(Price.symbol(for: viewModel.priceCurrencyCode))
                .foregroundStyle(.secondary)
                .fixedSize()
                .accessibilityIdentifier(AccessibilityIdentifiers.filterPriceCurrency)
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Layout.chipVerticalPadding)
        .glassEffect(.regular, in: .capsule)
        .contentShape(.capsule)
        .onTapGesture { isPriceFocused = true }
        .onChange(of: priceText) { applyTypedCap() }
        .onChange(of: viewModel.filter.maxPrice, initial: true) {
            if Price.parseAmount(priceText) != viewModel.filter.maxPrice {
                priceText = viewModel.filter.maxPrice.map { Price.inputText($0) } ?? ""
            }
        }
    }

    /// An empty text clears the cap, a readable one sets it, an unreadable one leaves the cap as it was, so the
    /// filter never holds a misread amount and the seeding `onChange` above never rewrites what is being typed.
    private func applyTypedCap() {
        let typed = priceText.trimmed
        if typed.isEmpty, viewModel.filter.maxPrice != nil {
            viewModel.updateFilter { $0.maxPrice = nil }
        } else if let amount = Price.parseAmount(typed), amount != viewModel.filter.maxPrice {
            viewModel.updateFilter { $0.maxPrice = amount }
        }
    }

    /// A menu picker shows only its selection, so the title sits on the left like the price row's.
    private var levelRow: some View {
        HStack {
            Text(AppBranding.Events.levelLabel)
            Spacer()
            SkillLevelPicker(selection: binding(\.skillLevel))
                .pickerStyle(.menu)
                .labelsHidden()
        }
    }

    /// Switching dates on proposes today plus a week; the pickers then edit that window day by day.
    @ViewBuilder private var datesSection: some View {
        Toggle(Copy.dates, isOn: datesEnabled)
        if let window = viewModel.filter.dateWindow {
            dateRow(Copy.from, selection: dateBinding(\.start, in: window))
            dateRow(Copy.until, selection: dateBinding(\.end, in: window))
        }
    }

    /// Title on the left, the compact picker at its natural size on the right: sharing a row with its own label made
    /// the picker shorten dates wider than today's to a numeric form.
    private func dateRow(_ title: String, selection: Binding<Date>) -> some View {
        HStack {
            Text(title)
            Spacer()
            DatePicker(title, selection: selection, displayedComponents: .date)
                .labelsHidden()
                .fixedSize()
        }
    }

    private var datesEnabled: Binding<Bool> {
        Binding(get: { viewModel.filter.dateWindow != nil },
                set: { on in viewModel.updateFilter { $0.dateWindow = on ? .proposal() : nil } })
    }

    /// Edits one end of the window as whole days, keeping the window valid (end never before start). Both pickers are
    /// handed the start of their day.
    private func dateBinding(_ end: WritableKeyPath<DateWindow, Date>, in window: DateWindow) -> Binding<Date> {
        Binding(get: { Calendar.current.startOfDay(for: window[keyPath: end]) }, set: { date in
            var edited = window
            edited[keyPath: end] = date
            viewModel.updateFilter { $0.dateWindow = .days(from: edited.start, to: edited.end) }
        })
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<EventFilter, Value>) -> Binding<Value> {
        Binding(get: { viewModel.filter[keyPath: keyPath] },
                set: { value in viewModel.updateFilter { $0[keyPath: keyPath] = value } })
    }
}

#Preview {
    let dependencies = AppDependencies.makeMock()
    EventFilterPanel(viewModel: dependencies.makeEventListViewModel(scope: .upcoming)) {}
}
