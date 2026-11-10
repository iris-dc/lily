import SwiftUI

/// The place name `TextField` of every form that asks for a spot, one row its callers place freely: the event form
/// keeps the geocoder's suggestions after the map row, the creation wizard stacks them right under the field. Given
/// the suggestion seam (`suggestions:query:search:`) it owns the debounce and the stale-drop rules; without one it is
/// the plain name row (`PlaceFields`). Focus is the field's own `@FocusState` unless the form moves focus of its own
/// (the event form's title row hands focus here on submit), which passes its `FocusState<Field?>.Binding` in with
/// `equals:` — the mechanism SwiftUI gives for focus shared across views, since `FocusState` cannot cross them as a
/// plain `Binding`.
struct PlaceNameField<Field: Hashable>: View {
    @Binding var name: String
    let placeholder: String
    let identifier: String
    let focus: FocusState<Field?>.Binding?
    let focusValue: Field?
    private let suggesting: Suggesting?
    @FocusState private var ownFocus: Bool

    /// The geocoder seam of a field that offers suggestions: where the rows live (the composing view owns the array,
    /// since the rows may render anywhere), when the typed name is worth asking about, and whom to ask.
    private struct Suggesting {
        let items: Binding<[PlaceSuggestion]>
        let query: () -> String?
        let search: (String) async -> [PlaceSuggestion]
    }

    init(name: Binding<String>,
         placeholder: String = AppBranding.Events.Create.locationNamePlaceholder,
         identifier: String,
         focus: FocusState<Field?>.Binding,
         equals focusValue: Field) {
        _name = name
        self.placeholder = placeholder
        self.identifier = identifier
        self.focus = focus
        self.focusValue = focusValue
        suggesting = nil
    }

    /// The field with the suggestion machinery: `query` says when the typed name is worth asking about
    /// (`EventDraft.placeSuggestionQuery`), `search` answers, and the places land in `suggestions` for the caller to
    /// draw (`PlaceSuggestionRows`) wherever its layout wants them.
    init(name: Binding<String>,
         placeholder: String = AppBranding.Events.Create.locationNamePlaceholder,
         identifier: String,
         focus: FocusState<Field?>.Binding,
         equals focusValue: Field,
         suggestions: Binding<[PlaceSuggestion]>,
         query: @escaping () -> String?,
         search: @escaping (String) async -> [PlaceSuggestion]) {
        _name = name
        self.placeholder = placeholder
        self.identifier = identifier
        self.focus = focus
        self.focusValue = focusValue
        suggesting = Suggesting(items: suggestions, query: query, search: search)
    }

    var body: some View {
        if let suggesting {
            nameField
                // One short breath after the last keystroke, then the geocoder's places for the typed name (`query`
                // says when to ask); an answer that comes back after the field was left, the name changed or a
                // suggestion was picked is dropped, since the search does not stop when cancelled.
                .task(id: name) { await refresh(suggesting) }
                .onChange(of: isFocused) {
                    if !isFocused { suggesting.items.wrappedValue = [] }
                }
        } else {
            nameField
        }
    }

    @ViewBuilder
    private var nameField: some View {
        let field = TextField(placeholder, text: $name)
            .textInputAutocapitalization(.words)
            .submitLabel(.done)
            .accessibilityIdentifier(identifier)
        if let focus, let focusValue {
            field.focused(focus, equals: focusValue)
        } else {
            field.focused($ownFocus)
        }
    }

    /// Whether this field holds the focus: the form's shared focus when one came in, the field's own otherwise.
    private var isFocused: Bool {
        if let focus, let focusValue { return focus.wrappedValue == focusValue }
        return ownFocus
    }

    private func refresh(_ suggesting: Suggesting) async {
        try? await Task.sleep(for: AppConfig.Events.placeSuggestionDebounce)
        guard !Task.isCancelled else { return }
        guard isFocused, let query = suggesting.query() else {
            suggesting.items.wrappedValue = []
            return
        }
        let found = await suggesting.search(query)
        guard !Task.isCancelled, isFocused, suggesting.query() == query else { return }
        suggesting.items.wrappedValue = found
    }
}

extension PlaceNameField where Field == Never {
    /// The plain field of a form that moves no focus of its own.
    init(name: Binding<String>,
         placeholder: String = AppBranding.Events.Create.locationNamePlaceholder,
         identifier: String) {
        _name = name
        self.placeholder = placeholder
        self.identifier = identifier
        focus = nil
        focusValue = nil
        suggesting = nil
    }

    /// The suggesting field owning its focus alone, for a layout that moves no focus of its own.
    init(name: Binding<String>,
         placeholder: String = AppBranding.Events.Create.locationNamePlaceholder,
         identifier: String,
         suggestions: Binding<[PlaceSuggestion]>,
         query: @escaping () -> String?,
         search: @escaping (String) async -> [PlaceSuggestion]) {
        _name = name
        self.placeholder = placeholder
        self.identifier = identifier
        focus = nil
        focusValue = nil
        suggesting = Suggesting(items: suggestions, query: query, search: search)
    }
}

/// The geocoder's suggestion rows, identical wherever a caller puts them: the event form keeps them after the map
/// row, the wizard right under the field. What a pick does — fill the draft, clear the rows, drop the focus — stays
/// with the caller, who owns that state.
struct PlaceSuggestionRows: View {
    let suggestions: [PlaceSuggestion]
    let pick: (PlaceSuggestion) -> Void

    var body: some View {
        ForEach(Array(suggestions.enumerated()), id: \.element.id) { index, suggestion in
            Button {
                pick(suggestion)
            } label: {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    // Semantic styles only: an asset colour (`Color.lilyAccent`, `.lilyInk`) stored in these rows
                    // crashed the list diff (EXC_BAD_ACCESS under ForEachState.item). The glyph keeps the button's
                    // accent tint; the title must not be accent at this size, so it takes the absolute label colour
                    // (`Color.primary`, not `.primary`, which only re-derives from the accent tint).
                    Label {
                        Text(suggestion.title).foregroundStyle(Color.primary)
                    } icon: {
                        Image(systemName: DesignTokens.Symbols.location)
                    }
                    if let subtitle = suggestion.subtitle {
                        Text(subtitle).font(LilyTheme.Fonts.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .accessibilityIdentifier(AccessibilityIdentifiers.createPlaceSuggestion(index))
        }
    }
}

#Preview {
    @Previewable @State var name = ""
    @Previewable @State var suggestions: [PlaceSuggestion] = []
    NavigationStack {
        Form {
            Section(AppBranding.Events.Create.whereSection) {
                PlaceNameField(name: $name,
                               identifier: AccessibilityIdentifiers.createLocationName,
                               suggestions: $suggestions,
                               query: { name.nonBlankTrimmed },
                               search: { query in
                                   [PlaceSuggestion(title: query, subtitle: nil, coordinate: AppConfig.Location.mockCenter)]
                               })
                PlaceSuggestionRows(suggestions: suggestions) { suggestion in
                    name = suggestion.title
                    suggestions = []
                }
            }
        }
    }
}
