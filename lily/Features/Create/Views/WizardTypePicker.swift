import SwiftUI

/// The type steps' picker (the owner's third design round, 2026-11-11): a search field over a compact two-column
/// grid of glass type cards, lighter than the full-width choice cards the longer type list outgrew. Tapping picks
/// and the page auto-advances; re-entering shows the current choice selected. Filtering is by localized name,
/// case-insensitive in the app's locale, so it matches what the cards say in the app's language; a query no name
/// contains shows a one-line empty state instead of a bare grid.
struct WizardTypePicker: View {
    /// The leading "Any type" entry of a nullable choice (the group's); the per-type entries are always offered.
    var anyTitle: String?
    let isSelected: (EventType?) -> Bool
    let pick: (EventType?) -> Void
    @State private var query = ""

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: DesignTokens.Spacing.sm, alignment: .top),
              count: DesignTokens.Layout.wizardTypeColumns)
    }

    var body: some View {
        searchField
        if showsAnyEntry || !visibleTypes.isEmpty {
            LazyVGrid(columns: columns, spacing: DesignTokens.Spacing.sm) {
                if showsAnyEntry, let anyTitle {
                    WizardTypeCard(title: anyTitle,
                                   systemImage: DesignTokens.Symbols.anyType,
                                   isSelected: isSelected(nil),
                                   identifier: AccessibilityIdentifiers.createTypeAny) { pick(nil) }
                }
                ForEach(visibleTypes, id: \.self) { type in
                    WizardTypeCard(title: type.displayName,
                                   systemImage: type.symbolName,
                                   isSelected: isSelected(type),
                                   identifier: AccessibilityIdentifiers.createEventType(type.wireName)) { pick(type) }
                }
            }
        } else {
            Text(AppBranding.Create.typeSearchNoMatch)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var showsAnyEntry: Bool { anyTitle.map(matches) ?? false }

    private var searchField: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: DesignTokens.Symbols.search)
                .foregroundStyle(.secondary)
            TextField(AppBranding.Create.typeSearch, text: $query)
                .autocorrectionDisabled()
                .accessibilityIdentifier(AccessibilityIdentifiers.createTypeSearch)
        }
        .lilyField()
    }

    private var visibleTypes: [EventType] {
        EventType.known.filter { matches($0.displayName) }
    }

    /// An empty query shows everything; otherwise the localized name must contain it, case-insensitively, folded by
    /// the app's locale (`AppLocale`), not the system's, so the fold matches the language the cards read in.
    private func matches(_ title: String) -> Bool {
        let query = query.trimmed
        return query.isEmpty || title.range(of: query, options: .caseInsensitive, locale: AppLocale.locale) != nil
    }
}

/// One compact glass card of the type grid: the symbol and name, the accent check on the current choice (accent on
/// the mark, never the words), the whole card the tap target.
private struct WizardTypeCard: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let identifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: systemImage)
                Text(title)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if isSelected {
                    Image(systemName: DesignTokens.Symbols.chosen)
                        .font(.footnote)
                        .foregroundStyle(Color.lilyAccent)
                }
            }
            .font(.subheadline)
            .padding(.horizontal, DesignTokens.Spacing.md)
            .frame(minHeight: DesignTokens.Layout.wizardTypeCardHeight)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular, in: .rect(cornerRadius: DesignTokens.Radius.md))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .lilyHoverable()
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier(identifier)
    }
}

#Preview {
    ContentScreen {
        ScrollView {
            WizardTypePicker(isSelected: { $0 == .padel }, pick: { _ in })
                .padding()
        }
    }
}
