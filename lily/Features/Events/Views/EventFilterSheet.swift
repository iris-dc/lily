import SwiftUI

/// Every filter criterion as a full-screen form, like the create forms: type chips, a distance slider, attendee and
/// time-of-day chips, level, dates and open spots, with Reset in the bar while anything is active and Done closing the
/// sheet. Every change applies at once; Done only closes.
struct EventFilterSheet: View {
    let viewModel: EventListViewModel
    let onDone: () -> Void

    private typealias Copy = AppBranding.Events.Filter

    var body: some View {
        NavigationStack {
            ContentScreen {
                form
            }
            .navigationTitle(Copy.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if viewModel.filter.isActive {
                        Button(Copy.reset) { viewModel.clearFilter() }
                            .lilyToolbarTextButton()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(Copy.done, action: onDone)
                        .lilyToolbarTextButton()
                }
            }
            .tint(Color.lilyAccent)
        }
    }

    private var form: some View {
        Form {
            Section(Copy.eventType) { typeChips }
            Section(Copy.distance) { distanceChoice }
            Section(Copy.attendees) { attendeeChips }
            Section(Copy.timeOfDay) { timeChips }
            Section {
                levelRow
                datesSection
                openSpotsRow
            }
        }
        .scrollContentBackground(.hidden)
        .readableColumn()
    }

    /// Multi-select behind the compact head-of-list flow; "Any type" is on while nothing is chosen.
    private var typeChips: some View {
        EventTypeMultiCompactPicker(anyTitle: Copy.anyType,
                                    anyIdentifier: AccessibilityIdentifiers.filterTypeAny,
                                    selected: viewModel.filter.types,
                                    onSelectAny: { viewModel.updateFilter { $0.types = [] } },
                                    onToggle: { viewModel.toggleType($0) })
    }

    /// Distance from the user's position, as a slider over the offered reach. Without a position the criterion cannot
    /// be judged, so the slider is replaced by a note.
    @ViewBuilder private var distanceChoice: some View {
        if viewModel.userLocation == nil {
            Text(Copy.locationUnavailable)
                .font(LilyTheme.Fonts.caption)
                .foregroundStyle(.secondary)
        } else {
            HStack(spacing: DesignTokens.Spacing.md) {
                Slider(value: distanceKilometers,
                       in: AppConfig.Events.filterRadiusRangeKilometers,
                       step: AppConfig.Events.filterRadiusStepKilometers)
                    .accessibilityIdentifier(AccessibilityIdentifiers.filterDistance)
                Text(Measurement(value: distanceMeters, unit: UnitLength.meters).roadText())
                    .font(LilyTheme.Fonts.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .fixedSize()
            }
        }
    }

    /// What the slider shows: the filter's radius, or its far end standing in for "anywhere" (a kept older filter).
    private var distanceMeters: Double {
        viewModel.filter.maxDistanceMeters ?? AppConfig.Events.filterRadiusRangeKilometers.upperBound * 1_000
    }

    private var distanceKilometers: Binding<Double> {
        Binding(get: { distanceMeters / 1_000 },
                set: { kilometers in viewModel.updateFilter { $0.maxDistanceMeters = kilometers * 1_000 } })
    }

    /// One floor at a time: how many people are already in; "Any" lifts it, as does tapping the chosen floor again.
    private var attendeeChips: some View {
        FlowLayout(spacing: DesignTokens.Spacing.md, rowSpacing: 0) {
            ChoiceChip(title: Copy.anyAttendees, isSelected: viewModel.filter.minAttendees == nil) {
                viewModel.updateFilter { $0.minAttendees = nil }
            }
            .accessibilityIdentifier(AccessibilityIdentifiers.filterAttendeesAny)
            ForEach(AppConfig.Events.filterAttendeeChoices, id: \.self) { floor in
                ChoiceChip(title: Copy.atLeast(floor), isSelected: viewModel.filter.minAttendees == floor) {
                    viewModel.updateFilter { $0.minAttendees = $0.minAttendees == floor ? nil : floor }
                }
                .accessibilityIdentifier(AccessibilityIdentifiers.filterAttendees(floor))
            }
        }
    }

    /// Multi-select like the types; "Any" is on while nothing is chosen.
    private var timeChips: some View {
        FlowLayout(spacing: DesignTokens.Spacing.md, rowSpacing: 0) {
            ChoiceChip(title: Copy.anyTime, isSelected: viewModel.filter.timesOfDay.isEmpty) {
                viewModel.updateFilter { $0.timesOfDay = [] }
            }
            .accessibilityIdentifier(AccessibilityIdentifiers.filterTimeAny)
            ForEach(TimeOfDay.allCases, id: \.self) { time in
                ChoiceChip(title: time.displayName, isSelected: viewModel.filter.timesOfDay.contains(time)) {
                    viewModel.toggleTime(time)
                }
                .accessibilityIdentifier(AccessibilityIdentifiers.filterTime(time))
            }
        }
    }

    /// The switch with the line saying what it hides; the title alone read as a riddle.
    private var openSpotsRow: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Toggle(Copy.openSpotsOnly, isOn: binding(\.openSpotsOnly))
            Text(Copy.openSpotsFootnote)
                .font(LilyTheme.Fonts.caption)
                .foregroundStyle(.secondary)
        }
    }

    /// A menu picker shows only its selection, so the title sits on the left like the date rows'.
    private var levelRow: some View {
        HStack {
            Text(AppBranding.Events.levelLabel)
            Spacer()
            SkillLevelPicker(selection: binding(\.skillLevel))
                .lilyMenuPicker()
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
    EventFilterSheet(viewModel: dependencies.makeEventListViewModel(scope: .upcoming)) {}
}
