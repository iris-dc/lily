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
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                header
                FilterSection(Copy.eventType) { typeChips }
                FilterSection(Copy.distance) { distanceChoice }
                FilterSection(Copy.maxPrice) { priceRow }
                levelRow
                datesSection
                Toggle(Copy.openSpotsOnly, isOn: binding(\.openSpotsOnly))
            }
            .padding(DesignTokens.Spacing.lg)
        }
        .frame(width: DesignTokens.Layout.filterPanelWidth)
        .presentationBackground(.clear)
        .tint(Color.lilyAccent)
    }

    private var header: some View {
        HStack {
            Text(Copy.title).font(LilyTheme.Fonts.cardTitle)
            Spacer()
            if viewModel.filter.isActive {
                Button {
                    viewModel.clearFilter()
                } label: {
                    Text(Copy.reset).tappableLabel()
                }
                .buttonStyle(.borderless)
                .font(LilyTheme.Fonts.caption)
            }
            Button(Copy.done, action: onDone)
                .lilyProminentButton(sizing: .fitted, controlSize: .small)
        }
    }

    /// Multi-select; "Any type" is on while nothing is chosen.
    private var typeChips: some View {
        FlowLayout(spacing: DesignTokens.Spacing.md, rowSpacing: 0) {
            ChoiceChip(title: Copy.anyType, isSelected: viewModel.filter.types.isEmpty) {
                viewModel.updateFilter { $0.types = [] }
            }
            .accessibilityIdentifier(AccessibilityIdentifiers.filterTypeAny)
            ForEach(viewModel.availableTypes, id: \.self) { type in
                ChoiceChip(title: type.displayName,
                           systemImage: type.symbolName,
                           isSelected: viewModel.filter.includes(type)) {
                    viewModel.toggleType(type)
                }
                .accessibilityIdentifier(AccessibilityIdentifiers.filterType(type))
            }
        }
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
                    Text(Measurement(value: meters, unit: UnitLength.meters).roadText).tag(Double?.some(meters))
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
    /// source while typing; the filter is parsed from it, and only a value set elsewhere (Reset, the chip) rewrites it.
    private var priceField: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            TextField(Copy.anyPrice, text: $priceText)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .focused($isPriceFocused)
                .frame(width: DesignTokens.Layout.filterPriceFieldWidth)
                .accessibilityIdentifier(AccessibilityIdentifiers.filterMaxPrice)
                .accessibilityLabel(Copy.maxPrice)
            Text(Price.symbol(for: AppConfig.Events.marketCurrencyCode))
                .foregroundStyle(.secondary)
                .fixedSize()
                .accessibilityHidden(true)
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Layout.chipVerticalPadding)
        .glassEffect(.regular, in: .capsule)
        .contentShape(.capsule)
        .onTapGesture { isPriceFocused = true }
        .onChange(of: priceText) {
            viewModel.updateFilter { $0.maxPrice = Self.price(from: priceText) }
        }
        .onChange(of: viewModel.filter.maxPrice, initial: true) {
            if Self.price(from: priceText) != viewModel.filter.maxPrice {
                priceText = viewModel.filter.maxPrice.map { $0.formatted(Self.priceFormat) } ?? ""
            }
        }
    }

    private static let priceFormat = Decimal.FormatStyle.number.precision(.fractionLength(0...2))

    /// Locale-aware ("6,5" and "6.5"); empty, unreadable or negative text means no cap.
    static func price(from text: String) -> Decimal? {
        guard let amount = try? priceFormat.parseStrategy.parse(text), amount >= 0 else { return nil }
        return amount
    }

    /// A menu picker shows only its selection, so the title sits on the left like the price row's.
    private var levelRow: some View {
        HStack {
            Text(Copy.level)
            Spacer()
            Picker(Copy.level, selection: binding(\.skillLevel)) {
                Text(Copy.anyLevel).tag(SkillLevel?.none)
                ForEach(SkillLevel.allCases, id: \.self) { level in
                    Text(level.displayName).tag(SkillLevel?.some(level))
                }
            }
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

/// Caption title over a criterion's control.
private struct FilterSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    init(_ title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text(title).font(LilyTheme.Fonts.caption).foregroundStyle(.secondary)
            content()
        }
    }
}

#Preview {
    let dependencies = AppDependencies.makeMock()
    EventFilterPanel(viewModel: dependencies.makeEventListViewModel(scope: .upcoming)) {}
}
